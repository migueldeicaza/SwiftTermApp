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

///
/// Surfaces the libssh2 `Session` APIs and puts them behind an actor, ensuring that all operations on it
/// are serialized.   This API surface is not only for the session, but also for any types that are thread-bound
/// to the session, like channels created from the session, or the SFTP API.
actor SessionActor {
    typealias queuedOp = ()->Bool
    
    // Handle to the libssh2 Session
    var sessionHandle: OpaquePointer!

    // Purely helps to initialize the Session object
    init (fakeSetup: Bool) { }
    
    /// Initializes the session actor with methods to send, receive and notify about any debug information
    /// - Parameters:
    ///  - send: the method that will be invoked by libssh2 to send data over the connection
    ///  - recv: the method that is invoked by libssh2 to receive data from the connection
    ///  - debug: method to invoke when we receive a debug message from the server
    ///  - opaque: the C-level context/closure.   This should point to the Session, and is allocated by the session.
    init (send: @escaping socketCbType, recv: @escaping socketCbType, disconnect: @escaping disconnectCbType, debug: @escaping debugCbType, opaque: UnsafeMutableRawPointer) {
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
        
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(disconnect, to: UnsafeMutableRawPointer.self))
        
        libssh2_session_set_blocking (sessionHandle, 0)
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: UnsafeMutableRawPointer.self))
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: UnsafeMutableRawPointer.self))
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_DEBUG, unsafeBitCast(debug, to: UnsafeMutableRawPointer.self))
    }
    
    var suspendedTasks = 0
    func track (task: @escaping queuedOp) {
        if task () {
            suspendedTasks += 1
            tasks.append (task)
        }
    }
    
    ///
    /// Calls into a libssh2 function that uses the convention that where a `LIBSSH2_ERROR_EAGAIN`
    /// return value indicates that the operation should be retried, but does so by waiting for new
    /// data to be made available on the channel.
    ///
    /// - Parameter callback: a method that is expecred to return an Int32, and one of the
    /// possible values is `LIBSSH2_ERROR_EAGAIN` which will trigger a new attempt to execute
    func callSsh (_ callback: @escaping ()->Int32) async -> Int32 {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let ret = callback()
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return true
                }
                c.resume(returning: ret)
                return false
            }
            track (task: op)
        }
    }

    ///
    /// Calls into a libssh2 function that returns a pointer value as a return, and that sets the
    /// libssh2 errno to `LIBSSH2_ERROR_EAGAIN` to indicate that there is not enough data
    /// availble and the operation should be retried.   If this is the case, then the operation is
    /// queued for exectuion until new data to be made available on the channel.
    ///
    /// - Parameter callback: a method that is expecred to return an Int32, and one of the
    /// possible values is `LIBSSH2_ERROR_EAGAIN` which will trigger a new attempt to execute
    /// - Returns: an optional pointer value.
    func callSshPtr<T> (_ callback: @escaping ()->T?) async -> T? {
        return await withUnsafeContinuation { c in
            let op: queuedOp = {
                let ret = callback()
                if ret == nil {
                    let code = libssh2_session_last_errno(self.sessionHandle)
                    if code == LIBSSH2_ERROR_EAGAIN {
                        return true
                    }
                }
                c.resume(returning: ret)
                return false
            }
            track (task: op)
        }
    }

    // These tasks return true if they should be kept on the list
    var tasks: [()->Bool] = []
    
    /// To be invoked when new data has been read from the network for the channel,
    /// this retries all pending tasks that were waiting for data to be made available.
    public func pingTasks () {
        let copy = tasks
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
        return await callSsh {
            libssh2_session_handshake(self.sessionHandle, 0)
        }
    }

    public var timeout: Date?
    
    public func userAuthenticationList (username: String) async -> [String] {
        let ptr = await callSshPtr {
            return libssh2_userauth_list (self.sessionHandle, username, UInt32(username.utf8.count))
        }
        guard let ptr = ptr else {
            return []
        }
        return String (validatingUTF8: ptr)?.components(separatedBy: ",") ?? []
    }
        
    public var authenticated: Bool {
        get {
            return libssh2_userauth_authenticated(sessionHandle) == 1
        }
    }
    
    public func userAuthKeyboardInteractive (username: String) async -> String? {
        return await authErrorToString(code: callSsh {
            let usernameCount = UInt32 (username.utf8.count)
            return libssh2_userauth_keyboard_interactive_ex(self.sessionHandle, username, usernameCount) { name, nameLen, instruction, instructionLen, numPrompts, prompts, responses, abstract in
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
        })
    }
    
    // TODO: we should likely handle the password change callback requirement:
    // The callback: If the host accepts authentication but requests that the password be changed,
    // this callback will be issued. If no callback is defined, but server required password change,
    // authentication will fail.
    //
    // TODO: the above is the last parameter to libssh2_userauth_password_ex
    public func userAuthPassword (username: String, password: String) async -> String? {
        return authErrorToString(code: await callSsh {
            let usernameCount = UInt32(username.utf8.count)
            let passwordCount = UInt32(password.utf8.count)
            
            return libssh2_userauth_password_ex (self.sessionHandle, username, usernameCount, password, passwordCount, nil)
        })
    }
    
    public func userAuthPublicKeyFromMemory (username: String, passPhrase: String, publicKey: String, privateKey: String) async -> String? {
        let ret = await callSsh {
            // Use the withCString rather than going to Data and then to pointers, because libssh2 ignores in some paths the size of the
            // parameters and instead relies on a NUL characters at the end of the string to determine the size.
            
            let usernameCount = username.utf8.count
            return privateKey.withCString {
                let privPtr = $0
                
                return publicKey.withCString {
                    let pubPtr = $0
                    return libssh2_userauth_publickey_frommemory(self.sessionHandle, username, usernameCount, pubPtr, strlen(pubPtr), privPtr, strlen(privPtr), passPhrase)
                }
            }
        }
        return authErrorToString(code: ret)
    }
    
    public func userAuthWithCallback (username: String, publicKey: Data, signCallback: @escaping (Data)->Data?) async -> String? {
        let ret = await callSsh {
            var rc: CInt = 0
            let cbData = callbackData (pub: publicKey, signCallback: signCallback)
            let ptrCbData = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
            ptrCbData.pointee = Unmanaged.passUnretained(cbData).toOpaque()
            
            
            publicKey.withUnsafeBytes {
                let pubPtr = $0.bindMemory(to: UInt8.self).baseAddress!
                
                let count = publicKey.count
                rc = libssh2_userauth_publickey (self.sessionHandle, username, pubPtr, count, authenticateCallback, ptrCbData)
            }
            return rc
        }
        return authErrorToString(code: ret)
    }
    
    public func makeKnownHost () -> LibsshKnownHost? {
        guard let kh = libssh2_knownhost_init (sessionHandle) else {
            return nil
        }
        return LibsshKnownHost (sessionActor: self, knownHost: kh)
    }
    
    
    public func getFingerprintBytes () -> [UInt8]? {
        guard let hashPointer = libssh2_hostkey_hash(sessionHandle, LIBSSH2_HOSTKEY_HASH_SHA256) else {
            return nil
        }
        
        let hash = UnsafeRawPointer(hashPointer).assumingMemoryBound(to: UInt8.self)
        
        return (0..<32).map({ UInt8(hash[$0]) })
    }
    
    public func getBanner () -> String {
        return String (cString: libssh2_session_banner_get(sessionHandle))
    }
    
    public func readFile (knownHost: LibsshKnownHost, filename: String) -> String? {
        let ret = libssh2_knownhost_readfile(knownHost.khHandle, filename, LIBSSH2_KNOWNHOST_FILE_OPENSSH)
        if ret < 0 {
            return libSsh2ErrorToString(error: ret)
        }
        return nil
    }
    
    public func disconnect (reason: Int32 = SSH_DISCONNECT_BY_APPLICATION, description: String) async {
        let _ = await callSsh {
            libssh2_session_disconnect_ex(self.sessionHandle, reason, description, "")
        }
    }
    
    // Channel APIs
    
    public func openChannel (type: String, windowSize: CUnsignedInt = 2*1024*1024, packetSize: CUnsignedInt = 32768, readCallback: @escaping (Channel, Data?, Data?)async->()) async -> OpaquePointer? {
        
        return await callSshPtr {
            return libssh2_channel_open_ex(self.sessionHandle, type, UInt32(type.utf8.count), windowSize, packetSize, nil, 0)
        }
    }
    
    public func setEnv (channel: Channel, name: String, value: String) async -> Int32 {
        return await callSsh {
            libssh2_channel_setenv_ex (channel.channelHandle, name, UInt32(name.utf8.count), value, UInt32(value.utf8.count))
        }
    }
    
    public func requestPseudoTerminal (channel: Channel, name: String, cols: Int, rows: Int) async -> Int32 {
        return await callSsh {
            libssh2_channel_request_pty_ex(channel.channelHandle, name, UInt32(name.utf8.count), nil, 0, Int32(cols), Int32(rows), LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
        }
    }
    
    public func ping (channel: Channel) async -> (Data?, Data?)? {
        // standard channel
        let channelHandle = channel.channelHandle
        let streamId: Int32 = 0
        var ret, retError: Int
        let bufferSize = channel.bufferSize
        ret = libssh2_channel_read_ex (channelHandle, streamId, channel.buffer, bufferSize)
        retError = libssh2_channel_read_ex (channelHandle, SSH_EXTENDED_DATA_STDERR, channel.bufferError, bufferSize)

        let data = ret >= 0 ? Data (bytesNoCopy: channel.buffer, count: ret, deallocator: .none) : nil
        let error = retError >= 0 ? Data (bytesNoCopy: channel.bufferError, count: retError, deallocator: .none) : nil
        if ret >= 0 || retError >= 0 {
            return (data, error)
        } else {
            return nil
        }

    }
    public func processStartup (channel: Channel, request: String, message: String?) async -> Int32 {
        return await callSsh {
            libssh2_channel_process_startup (channel.channelHandle, request, UInt32(request.utf8.count), message, message == nil ? 0 : UInt32(message!.utf8.count))
        }
    }
    
    public func setTerminalSize (channel: Channel, cols: Int, rows: Int, pixelWidth: Int, pixelHeight: Int) async {
        let _ = await callSsh {
            libssh2_channel_request_pty_size_ex(channel.channelHandle, Int32(cols), Int32(rows), Int32(pixelWidth), Int32(pixelHeight))
        }
    }
    
    public func close (channel: Channel) async {
        let _ = await callSsh {
            libssh2_channel_close(channel.channelHandle)
        }
    }
    
    public func send (channel: Channel, data: Data, callback: @escaping (Int)->()) async {
        if data.count == 0 {
            return
        }
        callback (Int (await callSsh {
            data.withUnsafeBytes { (unsafeBytes) in
                let bytes = unsafeBytes.bindMemory(to: CChar.self).baseAddress!
                
                
                let ret = libssh2_channel_write_ex(channel.channelHandle, 0, bytes, data.count)
                    
                if ret < 0 {
                    print ("DEBUG libssh2_channel_write_ex result: \(libSsh2ErrorToString(error:Int32(ret)))")
                }
                return Int32 (ret)
            }
        }))
    }
    
    public func exec (channel: Channel, command: String) async -> Int32 {
        await callSsh {
            libssh2_channel_process_startup (channel.channelHandle, "exec", 4, command, UInt32(command.utf8.count))
        }
    }
    
    public func free (channelHandle: OpaquePointer) {
        libssh2_channel_free(channelHandle)
    }
    
    // SFTP APIs
    public func openSftp () async -> OpaquePointer? {
        return await callSshPtr { libssh2_sftp_init(self.sessionHandle) }
    }
    
    func sftpStat (_ sftp: SFTP, path: String) async -> LIBSSH2_SFTP_ATTRIBUTES? {
        var attr: LIBSSH2_SFTP_ATTRIBUTES = LIBSSH2_SFTP_ATTRIBUTES()
        let pc = UInt32 (path.utf8.count)
        
        let ret = await callSsh {
            libssh2_sftp_stat_ex(sftp.sftpHandle, path, pc, LIBSSH2_SFTP_STAT, &attr)
        }
        return ret == 0 ? attr : nil
    }
    
    func sftpLlOpen (_ sftp: SFTP, path: String, flags: UInt, file: Bool) async -> OpaquePointer? {
        return await callSshPtr {
            libssh2_sftp_open_ex(sftp.sftpHandle, path, UInt32 (path.utf8.count), flags, 0, file ? LIBSSH2_SFTP_OPENFILE : LIBSSH2_SFTP_OPENDIR)
        }
    }
    
    public func sftpShutdown (_ sftpHandle: OpaquePointer) async {
        libssh2_sftp_shutdown (sftpHandle)
    }
        
    func sftpReadFile (_ sftp: SFTP, path: String, limit: Int) async -> [Int8]? {
        guard let f = await sftpLlOpen (sftp, path: path, flags: UInt (LIBSSH2_FXF_READ), file: true) else {
            return nil
        }
        var buffer: [Int8] = []
        let size = 8192
        var llbuffer = Array<Int8>.init(repeating: 0, count: size)
        var ret: Int = 0
        var left = limit
        let _ = await callSsh {
            repeat {
                ret = libssh2_sftp_read(f, &llbuffer, min (size, left))
                if ret == LIBSSH2_ERROR_EAGAIN {
                    return Int32 (ret)
                }
                if ret > 0 {
                    left -= ret
                    buffer.append(contentsOf: llbuffer [0..<ret])
                }
                if ret == 0 {
                    return Int32 (ret)
                }
            } while left > 0
            return 0
        }
        let _ = await callSsh {
            libssh2_sftp_close_handle(f)
        }
        return buffer
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

