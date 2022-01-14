//
//  Session.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 12/8/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//
// TODO:
//   Explore using libssh2_session blocking to avoid the manual timeout implementation in read
//   Explore removing all the DispatchQueues that I used while debugging this

import Foundation
import CSwiftSH
import Network

@_implementationOnly import CSSH

extension Data {
    public func getDump(indent: String = "") -> String {
        let res = self.withUnsafeBytes { data -> String in
            var hexstr = String()
            var txt = String ()
            var n = 0
            for i in data.bindMemory(to: UInt8.self) {
                if (n % 16) == 0 {
                    hexstr += " \(txt)\n" + String (format: "%04x: ", n)
                    txt = ""
                }
                n += 1
                hexstr += String(format: "%02X ", i)
                txt += (i > 32 && i < 127 ? String (Unicode.Scalar (i)) : ".")
            }
            hexstr += " \(txt)"
            return hexstr.replacingOccurrences(of: "\n", with: "\n\(indent)")
        }
        return res
    }
    
    public func dump() {
        print (getDump ())
    }
}

protocol SessionDelegate: AnyObject {
    // Called to authenticate the user on the network queue
    func authenticate (session: Session) -> String?
    
    // Called if we failed to login on the network queue
    func loginFailed (session: Session, details: String)
    
    // Called when we are authenticated on the network queue
    func loggedIn (session: Session)
}

class Session: CustomDebugStringConvertible {
    // Handle to the libssh2 Session
    var sessionHandle: OpaquePointer!
    //var sshQueue: DispatchQueue
    
    // Where we post interesting events about this session
    weak var delegate: SessionDelegate!
    
    typealias disconnectType = @convention(c) (UnsafeRawPointer, CInt,
                                               UnsafePointer<CChar>, CInt,
                                               UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void
    
    
    // Turns the libssh2 abstract pointer (which is a pointer to the value passed) into a strong type
    static func getSession (from abstract: UnsafeRawPointer) -> Session {
        let ptr = abstract.bindMemory(to: UnsafeRawPointer.self, capacity: 1)
        return Unmanaged<Session>.fromOpaque(ptr.pointee).takeUnretainedValue()
    }

    public init (delegate: SessionDelegate) {
        libssh2_init(0)
        //sshQueue = DispatchQueue.global(qos: .userInitiated)
        self.delegate = delegate
        
        let opaqueHandle = UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque())
        sessionHandle = libssh2_session_init_ex(nil, nil, nil, opaqueHandle)
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
        
        let callback: disconnectType = { sessionPtr, reason, message, messageLen, language, languageLen, abstract in
            let session = Session.getSession(from: abstract)
            
            print ("On session: \(session)")
            print ("Disconnected")
            abort ()
        }
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(callback, to: UnsafeMutableRawPointer.self))
        // TODO: wish of mine: should set all the callbacjs, and handle every scenario
        setupCallbacks ()
    }
    
    var debugDescription: String {
        get { "<Invalid session: use a subclass>" }
    }
    
    // Should setup the read/write callbacks
    public func setupCallbacks () {
    }
    
    func handshake () {
        while libssh2_session_handshake(sessionHandle, 0) == LIBSSH2_ERROR_EAGAIN {
            // Repeat while we get EAGAIN
        }
    }
    
    // Returns an array of authentication methods available for the specified user
    public func userAuthenticationList (username: String) -> [String] {
        var result: UnsafeMutablePointer<CChar>!
        
        timeout = Date (timeIntervalSinceNow: 2)
        result = libssh2_userauth_list (sessionHandle, username, UInt32(username.utf8.count))
        timeout = nil
        if result == nil {
            let code = libssh2_session_last_errno(sessionHandle)
            print ("Got error: ssh2error: \(code)")
            return []
        }
        return String (validatingUTF8: result)?.components(separatedBy: ",") ?? []
    }
    
    public func getFingerprintBytes () -> [UInt8]? {
        guard let hashPointer = libssh2_hostkey_hash(sessionHandle, LIBSSH2_HOSTKEY_HASH_SHA256) else {
            return nil
        }
        
        let hash = UnsafeRawPointer(hashPointer).assumingMemoryBound(to: UInt8.self)
        
        return (0..<32).map({ UInt8(hash[$0]) })
    }
    
    public func getFingerprint () -> String? {
        guard let bytes = getFingerprintBytes() else {
            return nil
        }
        let d = Data (bytes)
        return "SHA256:" + d.base64EncodedString()
    }
    
    var timeout: Date?
    
    func setupSshConnection ()
    {
        handshake()
        let res = String (cString: libssh2_session_banner_get(sessionHandle))
        let failureReason = delegate.authenticate(session: self)
        if authenticated {
            delegate.loggedIn(session: self)
        } else {
            delegate.loginFailed (session: self, details: failureReason ?? "Internal error: authentication claims it worked, but libssh2 state indicates it is not authenticated")
        }
    }
    
    public var authenticated: Bool {
        get {
            libssh2_userauth_authenticated(sessionHandle) == 1
        }
    }
    
    /// <#Description#>
    /// - Returns: bil on success, or a user-visible description on error
    public func userAuthPassword (username: String, password: String) -> String? {
        // TODO: we should likely handle the password change callback requirement:
        // The callback: If the host accepts authentication but requests that the password be changed,
        // this callback will be issued. If no callback is defined, but server required password change,
        // authentication will fail.
        
        // Attempt basic password authentication. Note that many SSH servers which appear to support
        // ordinary password authentication actually have it disabled and use Keyboard Interactive
        // authentication (routed via PAM or another authentication backed) instead.
        var ret: CInt
        repeat {
            ret = libssh2_userauth_password_ex (sessionHandle, username, UInt32(username.utf8.count), password, UInt32(password.utf8.count), nil)
        } while ret == LIBSSH2_ERROR_EAGAIN
        switch ret {
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
    
    var channels: [Channel] = []
    
    public func openChannel (type: String, windowSize: CUnsignedInt = 2*1024*1024, packetSize: CUnsignedInt = 32768, readCallback: @escaping (Channel, Data?, Data?)->())  -> Channel? {
        var ret: OpaquePointer?
        
        repeat {
            ret = libssh2_channel_open_ex(sessionHandle, type, UInt32(type.utf8.count), windowSize, packetSize, nil, 0)
        } while ret == nil && libssh2_session_last_errno (sessionHandle) == LIBSSH2_ERROR_EAGAIN
        guard let channelHandle = ret else {
            return nil
        }
        let channel = Channel (session: self, channelHandle: channelHandle, readCallback: readCallback)
        channels.append(channel)
        return channel
    }
}

// A session powered by sockets
class SocketSession: Session {
    var host: String
    var port: UInt16
    var connection: NWConnection
    var networkQueue: DispatchQueue
    
    public init (host: String, port: UInt16, delegate: SessionDelegate) {
        self.host = host
        self.port = port
        
        connection = NWConnection(host: NWEndpoint.Host (host), port: NWEndpoint.Port (integerLiteral: port), using: .tcp)
        networkQueue = DispatchQueue.global(qos: .userInitiated)
        super.init (delegate: delegate)
        connection.stateUpdateHandler = connectionStateHandler
        connection.start (queue: networkQueue)
    }
    
    deinit{
        print ("SocketSession being disposed")
    }
    
    static func getSocketSession (from abstract: UnsafeRawPointer) -> SocketSession {
        let ptr = abstract.bindMemory(to: UnsafeRawPointer.self, capacity: 1)
        return Unmanaged<SocketSession>.fromOpaque(ptr.pointee).takeUnretainedValue()
    }

    override var debugDescription: String {
        get {
            return "SocketSession on \(host):\(port) status=\(connection.state)"
        }
    }
    
    func log (_ msg: String) {
        print ("SOCKET_SESSION_STATE: \(msg)")
    }
    
    var buffer: Data = Data ()
    var bufferEOF = false
    var bufferLock = NSLock ()
    var bufferError: NWError? = nil
    
    // Starts the Network IO, accumultates data into buffer, and tracks
    // the end of data in bufferEof ("no more data after it is consumed"
    func startIO () {
        //print ("startIO: Awaiting more data")
        connection.receive(minimumIncompleteLength: 0, maximumLength: 32*1024) { data, context, isComplete, error in
            var restart = true
            
            self.bufferLock.lock()
            if let received = data {
                //print ("StartIO: Got data \(data?.count ?? -1) appending to \(self.buffer.count)")
                //print (data!.getDump(indent: "   IO> "))
                self.buffer.append(received)
            } else {
                print ("Data is null")
            }
            self.bufferError = error
            
            if let ctxt = context {
                if isComplete && ctxt.isFinal {
                    self.bufferEOF = true
                    restart = false
                }
            }
            self.bufferLock.unlock()
            //self.sshQueue.sync {
            DispatchQueue.main.sync {
                for channel in self.channels {
                    channel.ping()
                }
            }
            if restart {
                self.startIO()
            } else {
                abort()
            }
        }
    }
       
    func connectionStateHandler (state: NWConnection.State) {
        switch state {
            
        case .setup:
            log ("setup")
        case .waiting(let detail):
            log ("waiting (\(detail)")
        case .preparing:
            log ("preparing")
        case .ready:
            log ("ready")
            startIO()
            //sshQueue.async {
                self.setupSshConnection ()
            //}
        case .failed(_):
            log ("failed")
        case .cancelled:
            log ("canceled")
        @unknown default:
            log ("ERROR - UNKNONWN")
        }
    }
    
    // Encodes the error received from the Network framework into the libssh2 expected convention of -errno for an error, or a value on success
    static func successOrError (_ error: NWError?, n: Int) -> ssize_t {
        if let gotError = error {
            // TODO: should return -errno
            print ("SocketSession, Error, \(gotError)")
            switch gotError {
            case .posix(let posix):
                print ("Got posix: \(posix)")
            case .dns(let dns):
                print ("Got dns: \(dns)")
            case .tls(let tls):
                print ("Tls, should never happen \(tls)")
            default:
                return -1
            }
            
            return -1
        }
        return n
    }
    
    // Callback invoked by libssh2 to send data over our connection
    static func send_callback(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt, abstract: UnsafeRawPointer) -> ssize_t {
        let session = SocketSession.getSocketSession(from: abstract)
        
        let connection = session.connection
        let data = Data (bytes: buffer, count: length)
        //print ("Sending \(data.count) bytes on \(session)")
        //print (data.getDump(indent: "   sending>"))
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: NWError? = nil
        connection.send (content: data, completion: .contentProcessed { error in
            //print ("Send completed for \(data.count) bytes")
            sendError = error
            semaphore.signal()
        })
        semaphore.wait()
        return successOrError (sendError, n: data.count)
    }

//    static func recv_callback_new(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt, abstract: UnsafeRawPointer) -> ssize_t {
//        let session = SocketSession.getSocketSession(from: abstract)
//        //var blocking = libssh2_session_get_blocking(session.sessionHandle)
//        //print ("Recv On session: \(session), blocking: \(blocking) max: \(length)")
//
//        let semaphore = DispatchSemaphore(value: 0)
//        let connection = session.connection
//        var recvError: NWError? = nil
//        var count = 0
//        connection.receive(minimumIncompleteLength: 0, maximumLength: length) { data, context, isComplete, error in
//            recvError = error
//            if let data = data {
//                let x = UnsafeMutablePointer<UInt8> (OpaquePointer (buffer))
//
//
//                data.copyBytes(to: x, count: data.count)
//                //print ("Received: \(data.count) \(data.hexadecimalString())")
//                count = data.count
//            }
//            semaphore.signal()
//        }
//        semaphore.wait ()
//        return successOrError(recvError, n: count)
//    }
    
    static func recv_callback(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt, abstract: UnsafeRawPointer) -> ssize_t {
        let session = SocketSession.getSocketSession(from: abstract)
        //var blocking = libssh2_session_get_blocking(session.sessionHandle)
        //print ("Recv On session: \(session), blocking: \(blocking) max: \(length)")

        let x = UnsafeMutablePointer<UInt8> (OpaquePointer (buffer))
        var consumedBytes = 0
        var wasError: NWError? = nil
        var i = 0
        var left: Int = 0
        while true {
            session.bufferLock.lock ()
            consumedBytes = min (length, session.buffer.count)
            session.buffer.copyBytes(to: x, count: consumedBytes)
            session.buffer = session.buffer.dropFirst(consumedBytes)
            wasError = session.buffer.count == 0 && session.bufferError != nil ? session.bufferError : nil
            left = session.buffer.count
            session.bufferLock.unlock()
            i += 1
            
            // This is necessary for certain APIs in libssh2 that expect data to be received,
            // and do not cope with retrying properly: userauth_list for instance will happily
            // return EAGAIN, but if invoked at a later point again, it will resent the request
            // to the server, confusing the server.
            //
            // so we setup a timeout system that will guarantee data delivery within that timeout
            // rather than returning "I do not have data yet"
            if consumedBytes == 0 {
                if let sessTimeout = session.timeout {
                    //print ("Waiting for timeout \(sessTimeout) at \(Date())")
                    if Date () < sessTimeout {
                        //print ("Waiting \(i)")
                        Thread.sleep(forTimeInterval: 0.02)
                    } else {
                        break
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        if consumedBytes == 0 {
            //print ("Returning -EAGAIN")
            return Int (-EAGAIN)
        }
        let ret = successOrError(wasError, n: consumedBytes)
        //print ("Returning \(ret) bytes left = \(left)")
        return ret;
    }
    
    typealias socketCbType = @convention(c) (libssh2_socket_t, UnsafeRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
    
    public override func setupCallbacks () {
        let send: socketCbType = { socket, buffer, length, flags, abstract in
            SocketSession.send_callback(socket: socket, buffer: buffer, length: length, flags: flags, abstract: abstract)
        }
        
        let recv: socketCbType = { socket, buffer, length, flags, abstract in
            return SocketSession.recv_callback(socket: socket, buffer: buffer, length: length, flags: flags, abstract: abstract)
        }
        libssh2_session_set_blocking (sessionHandle, 0)
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: UnsafeMutableRawPointer.self))
        libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: UnsafeMutableRawPointer.self))
    }
}

class ProxySession: Session {
    public override init (delegate: SessionDelegate)
    {
        super.init (delegate: delegate)
    }
    
    public override func setupCallbacks () {
    }
}

