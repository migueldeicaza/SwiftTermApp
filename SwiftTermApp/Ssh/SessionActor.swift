//
// TODO:
//  - Handle disconnect
//  - Do I still care about timeout as a global?   With this async framework, perhaps the timeout needs to be implemented elsewhere
//
//  SessionActor.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 2/3/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//
import Foundation
import CSwiftSH
import Network
import CryptoKit

@_implementationOnly import CSSH

typealias socketCbType = @convention(c) (libssh2_socket_t, UnsafeRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
typealias debugCbType  = @convention(c) (libssh2_socket_t, CInt, UnsafeRawPointer, CInt, UnsafeRawPointer, CInt, UnsafeRawPointer) -> ()
typealias disconnectCbType = @convention(c) (UnsafeRawPointer, CInt,
                                           UnsafePointer<CChar>, CInt,
                                           UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void

typealias queuedOp = ()->Bool

actor SessionActor {
    // Handle to the libssh2 Session
    var sessionHandle: OpaquePointer!

    init (fakeSetup: Bool) { }
    init (send: @escaping socketCbType, recv: @escaping socketCbType, debug: @escaping debugCbType, opaque: UnsafeMutableRawPointer) {
        libssh2_init (0)
        sessionHandle = libssh2_session_init_ex(nil, nil, nil, opaque)
        let flags: Int32 = 0
        libssh2_trace(sessionHandle, flags)
        libssh2_trace_sethandler(sessionHandle, nil, { session, context, data, length in
            var str: String
            if let ptr = data {
                str = String (cString: ptr)
            } else {
                str = "<null>"
            }
            print ("Trace callback: \(str)")
        })
        
        // TODO
//        let callback: disconnectType = { sessionPtr, reason, message, messageLen, language, languageLen, abstract in
//            let session = Session.getSession(from: abstract)
//
//            print ("On session: \(session)")
//            print ("Disconnected")
//            session.disconnect(reason: SSH_DISCONNECT_CONNECTION_LOST, description: "")
//        }
        //libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(callback, to: UnsafeMutableRawPointer.self))
        
        libssh2_session_set_blocking (sessionHandle, 0)
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: UnsafeMutableRawPointer.self))
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: UnsafeMutableRawPointer.self))
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_DEBUG, unsafeBitCast(debug, to: UnsafeMutableRawPointer.self))
    }

    // These tasks return true if they should be kept on the list
    var tasks: [()->Bool] = []
    
    public func pingTasks () {
        var copy = tasks
        tasks = []
        
        for task in copy {
            if task() {
                tasks.append(task)
            }
        }
    }
    
    public func hostKey () -> (key: [Int8], type: Int32)? {
        var len: Int = 0
        var type: Int32 = 0

        let ptr = libssh2_session_hostkey(sessionHandle, &len, &type)
        if ptr == nil {
            return nil
        }
        let data = UnsafeBufferPointer (start: ptr, count: len)
        return (data.map { $0 }, type)
    }

    public func handshake () async -> Int32 {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let ret = libssh2_session_handshake(self.sessionHandle, 0)
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return true
                }
                c.resume(returning: ret)
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }

    public var timeout: Date?
    
    public func userAuthenticationList (username: String) async -> [String] {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                var result: UnsafeMutablePointer<CChar>!
                
                self.timeout = Date (timeIntervalSinceNow: 2)
                result = libssh2_userauth_list (self.sessionHandle, username, UInt32(username.utf8.count))
                self.timeout = nil
                if result == nil {
                    let code = libssh2_session_last_errno(self.sessionHandle)
                    if code == LIBSSH2_ERROR_EAGAIN {
                        return true
                    }
                    c.resume(returning: [])
                } else {
                    c.resume (returning: String (validatingUTF8: result)?.components(separatedBy: ",") ?? [])
                }
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }
        
    public var authenticated: Bool {
        get {
            return libssh2_userauth_authenticated(sessionHandle) == 1
        }
    }
    
    public func userAuthKeyboardInteractive (username: String) async -> String? {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let usernameCount = UInt32 (username.utf8.count)
                let ret = libssh2_userauth_keyboard_interactive_ex(self.sessionHandle, username, usernameCount) { name, nameLen, instruction, instructionLen, numPrompts, prompts, responses, abstract in
                    let session = Session.getSession(from: abstract!)

                    for i in 0..<Int(numPrompts) {
                        guard let promptI = prompts?[i], let text = promptI.text else {
                            continue
                        }
                        
                        let data = Data (bytes: UnsafeRawPointer (text), count: Int(promptI.length))
                        
                        guard let challenge = String (data: data, encoding: .utf8) else {
                            continue
                        }
                        
                        let password = session.promptFunc! (challenge)
                        let response = password.withCString {
                            LIBSSH2_USERAUTH_KBDINT_RESPONSE(text: strdup($0), length: UInt32(strlen(password)))
                        }
                        responses?[i] = response
                    }
                }
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return true
                }
                c.resume(returning: authErrorToString(code: ret))
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }
    
    public func makeKnownHost () -> LibsshKnownHost? {
        guard let kh = libssh2_knownhost_init (sessionHandle) else {
            return nil
        }
        return LibsshKnownHost (sessionActor: self, knownHost: kh)
    }
    
    public func readFile (_ khHandle: OpaquePointer, filename: String) -> String? {
        let ret = libssh2_knownhost_readfile(khHandle, filename, LIBSSH2_KNOWNHOST_FILE_OPENSSH)
        if ret < 0 {
            return libSsh2ErrorToString(error: ret)
        }
        return nil
    }
    
    public func openChannel (type: String, windowSize: CUnsignedInt = 2*1024*1024, packetSize: CUnsignedInt = 32768, readCallback: @escaping (Channel, Data?, Data?)->()) async -> Channel? {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                var ret: OpaquePointer?
                
                let typeCount = UInt32(type.utf8.count)
                ret = libssh2_channel_open_ex(self.sessionHandle, type, typeCount, windowSize, packetSize, nil, 0)
                if ret == nil {
                    if libssh2_session_last_errno (self.sessionHandle) == LIBSSH2_ERROR_EAGAIN {
                        return true
                    }
                    c.resume(returning: nil)
                } else {
                    let channel = Channel (session: self, channelHandle: ret!, readCallback: readCallback)
                    c.resume(returning: channel)
                }
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }
    
    public func channelSetEnv (_ channelHandle: OpaquePointer, name: String, value: String) async -> Int32 {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let ret = libssh2_channel_setenv_ex (channelHandle, name, UInt32(name.utf8.count), value, UInt32(value.utf8.count))
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return true
                }
                c.resume(returning: ret)
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }
    
    public func requestPseudoTerminal (_ channelHandle: OpaquePointer, name: String, cols: Int, rows: Int) async -> Int32 {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let ret = libssh2_channel_request_pty_ex(channelHandle, name, UInt32(name.utf8.count), nil, 0, Int32(cols), Int32(rows), LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return true
                }
                c.resume(returning: ret)
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }
    
    public func processStartup (_ channelHandle: OpaquePointer, request: String, message: String?) async -> Int32 {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let ret = libssh2_channel_process_startup (channelHandle, request, UInt32(request.utf8.count), message, message == nil ? 0 : UInt32(message!.utf8.count))
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return true
                }
                c.resume(returning: ret)
                return false
            }
            if op() {
                tasks.append(op)
            }
        }
    }
}
    
// Returns nil on success, or a description of the code on error
public func authErrorToString (code: CInt) -> String? {
    switch code {
    case 0:
        // We are fine, return
        return nil
    case LIBSSH2_ERROR_ALLOC:
        // WE are doomed, return
        return "Memory allocation failure"
    case LIBSSH2_ERROR_SOCKET_SEND:
        // We are doomed return, upper Network layer will notify of this problem
        return "Unable to send data to remote host"
    case LIBSSH2_ERROR_PASSWORD_EXPIRED:
        // the password expired, but we failed to change it (to fix, we will need to provide a callback)
        return "Password expired"
    case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
        // Failed, try the next password
        return "Password authentication failed"
    default:
        // Unknown error, return
        return "Unknown error during authentication"
    }
}

