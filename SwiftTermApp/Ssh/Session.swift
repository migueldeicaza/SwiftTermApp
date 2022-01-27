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
import CryptoKit

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

var sshQueue: DispatchQueue = DispatchQueue.init(label: "ssh-queue", qos: .userInitiated)

class Session: CustomDebugStringConvertible {
    
    // Handle to the libssh2 Session
    var sessionHandle: OpaquePointer!
    
    var channelsLock = NSLock ()
    
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
        self.delegate = delegate
        channelsLock = NSLock ()

        sshQueue.sync {
            libssh2_init (0)
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
                session.disconnect(reason: SSH_DISCONNECT_CONNECTION_LOST, description: "")
            }
            libssh2_session_callback_set(sessionHandle, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(callback, to: UnsafeMutableRawPointer.self))
            // TODO: wish of mine: should set all the callbacjs, and handle every scenario
            setupCallbacks ()
        }
    
    }
    
    var debugDescription: String {
        get { "<Invalid session: use a subclass>" }
    }
    
    // Should setup the read/write callbacks
    public func setupCallbacks () {
    }
    
    // Returns the key and type for the host
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
    public private(set) var banner: String = ""
    
    func setupSshConnection ()
    {
        handshake()
        banner = String (cString: libssh2_session_banner_get(sessionHandle))
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
    
    // Returns nil on success, or a description of the code on error
    func authErrorToString (code: CInt) -> String? {
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
    
    /// Performs a username/password authentication
    /// - Returns: nil on success, or a user-visible description on error
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
        return authErrorToString(code: ret)
    }
    
    var promptFunc: ((String)->String)?
    
    /// Performs an interactive user authentication for the specified username
    /// - Parameter prompt: method to invoke to present the prompt to the user
    /// - Returns: nil on success, or a user-visible description on error
    public func userAuthKeyboardInteractive (username: String, prompt: @escaping (String)->String) -> String? {
        var ret: CInt
        self.promptFunc = prompt
        
        repeat {
            ret = libssh2_userauth_keyboard_interactive_ex(sessionHandle, username, UInt32 (username.utf8.count)) { name, nameLen, instruction, instructionLen, numPrompts, prompts, responses, abstract in
                for i in 0..<Int(numPrompts) {
                    guard let prompt = prompts?[i], let text = prompt.text else {
                        continue
                    }

                    let data = Data (bytes: UnsafeRawPointer (text), count: Int(prompt.length))

                    guard let challenge = String (data: data, encoding: .utf8) else {
                        continue
                    }

                    let session = Session.getSession (from: abstract!)
                    let password = session.promptFunc! (challenge)
                    let response = password.withCString {
                         LIBSSH2_USERAUTH_KBDINT_RESPONSE(text: strdup($0), length: UInt32(strlen(password)))
                    }
                    responses?[i] = response
                }
            }
        } while ret == LIBSSH2_ERROR_EAGAIN
        self.promptFunc = nil
        return authErrorToString(code: ret)
    }
    
    /// Authenticates using the provided public/private key pairs
    /// - Returns: nil on success, or a user-visible description on error
    public func userAuthPublicKeyFromMemory (username: String, password: String, publicKey: String, privateKey: String) -> String? {
        var ret: CInt = 0
        
        // Use the withCString rather than going to Data and then to pointers, because libssh2 ignores in some paths the size of the
        // parameters and instead relies on a NUL characters at the end of the string to determine the size.
        
        privateKey.withCString {
            let privPtr = $0
            
            publicKey.withCString {
                let pubPtr = $0
                repeat {
                    ret = libssh2_userauth_publickey_frommemory(sessionHandle, username, username.utf8.count, pubPtr, strlen(pubPtr), privPtr, strlen(privPtr), password)
                } while ret == LIBSSH2_ERROR_EAGAIN
            }
        }
        return authErrorToString(code: ret)
    }
    
    
    
    /// Authenticates the session using a callback method
    /// - Parameter signCallback: method that receives a Data to be signed, and returns the signed data on success, nil on error
    /// - Returns:nil on success, or a user-visible description on error
    public func userAuthWithCallback (username: String, publicKey: Data, signCallback: @escaping (Data)->Data?) -> String? {
        var ret: CInt = 0
        let cbData = callbackData (pub: publicKey, signCallback: signCallback)
        let ptrCbData = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
        ptrCbData.pointee = Unmanaged.passUnretained(cbData).toOpaque()

        //libssh2_session_set_timeout (self.sessionHandle, 0)
        
        publicKey.withUnsafeBytes {
            let pubPtr = $0.bindMemory(to: UInt8.self).baseAddress!

            let count = publicKey.count
            repeat {
                ret = libssh2_userauth_publickey (sessionHandle, username, pubPtr, count, authenticateCallback, ptrCbData)
            } while ret == LIBSSH2_ERROR_EAGAIN
        }
        return authErrorToString(code: ret)
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
        return channel
    }
    
    public func activate (channel: Channel) {
        channelsLock.lock()
        channels.append(channel)
        channelsLock.unlock()
    }
    
    public func makeKnownHost () -> LibsshKnownHost? {
        guard let kh = libssh2_knownhost_init (sessionHandle) else {
            return nil
        }
        return LibsshKnownHost (knownHost: kh)
    }
    
    public enum FingerprintHashType {
        case md5
        case sha1
        case sha256
    }
    
    public func fingerprintBytes(_ hashType: FingerprintHashType) -> [UInt8]? {
        let type: Int32
        let length: Int

        switch hashType {
            case .md5:
                type = LIBSSH2_HOSTKEY_HASH_MD5
                length = 16
            case .sha1:
                type = LIBSSH2_HOSTKEY_HASH_SHA1
                length = 20
            case .sha256:
                type = LIBSSH2_HOSTKEY_HASH_SHA256
                length = 32
        }

        guard let hashPointer = libssh2_hostkey_hash(self.sessionHandle, type) else {
            return nil
        }
        
        let hash = UnsafeRawPointer(hashPointer).assumingMemoryBound(to: UInt8.self)
        
        return (0..<length).map({ UInt8(hash[$0]) })
    }

    public func disconnect (reason: Int32 = SSH_DISCONNECT_BY_APPLICATION, description: String) {
        var ret: CInt
        repeat {
            ret = libssh2_session_disconnect_ex(sessionHandle, reason, description, "")
        } while ret == LIBSSH2_ERROR_EAGAIN
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
            self.channelsLock.lock()
            let copy = self.channels
            self.channelsLock.unlock()
            
            for channel in copy {
                sshQueue.sync {
                    channel.ping()
                }
            
            }
            if restart {
                self.startIO()
            } else {
                // Handle, this happens if the connection is reset for example - 
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
            sshQueue.sync {
                self.setupSshConnection ()
            }
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
                return ssize_t (-posix.rawValue)
            case .dns(let dns):
                print ("Got dns: \(dns)")
                return -1
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
        //var left: Int = 0
        
        while true {
            session.bufferLock.lock ()
            consumedBytes = min (length, session.buffer.count)
            session.buffer.copyBytes(to: x, count: consumedBytes)
            session.buffer = session.buffer.dropFirst(consumedBytes)
            wasError = session.buffer.count == 0 && session.bufferError != nil ? session.bufferError : nil
            //left = session.buffer.count
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
    
    public override func disconnect (reason: Int32 = SSH_DISCONNECT_BY_APPLICATION, description: String) {
        super.disconnect(reason: reason, description: description)
        connection.forceCancel()
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

// Used to pass data into the authenticateCallback
class callbackData {
    internal init(pub: Data, signCallback: @escaping (Data)->Data?) {
        self.pub = pub
        self.signCallback = signCallback
    }

    var pub: Data
    var signCallback: (_ data: Data) -> Data?
}

// Support function for authenticating by callback
func authenticateCallback (session: OpaquePointer?,
                           sig: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
                           sig_len: UnsafeMutablePointer<Int>?,
                           data: UnsafePointer<UInt8>?,
                           data_len: Int,
                           abstract: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32 {

    func encode (_ int: Int) -> Data {
        var bigEndianInt = Int32 (int).bigEndian
        return Data (bytes: &bigEndianInt, count: 4)
    }

    func encode (data: Data) -> Data {
        return encode (data.count) + data
    }

    let cbData: callbackData = Unmanaged.fromOpaque (abstract!.pointee!).takeUnretainedValue()

    let data = Data(bytes: data!, count: data_len)
    guard let signedData = cbData.signCallback (data) else {
        return -1
    }

    // While malloc is technically correct, this is swappable by users of libssh2, since we
    // own libssh2, we can use malloc.
    guard let target = malloc (signedData.count) else {
        print ("Not enough ram to allocate \(signedData.count)")
        return -1
    }
   
    var rawmaybe: Data? = nil
    if #available(iOS 13.0, macOS 10.15, *) {
        rawmaybe = try? CryptoKit.P256.Signing.ECDSASignature(derRepresentation: signedData).rawRepresentation
    }
   
    guard let raw = rawmaybe else {
        return -1
    }
    let rawLength = raw.count / 2

    // Check if we need to pad with 0x00 to prevent certain
    // ssh servers from thinking r or s is negative
    let paddingRange: ClosedRange<UInt8> = 0x80...0xFF
    var r = Data(raw[0..<rawLength])
    if paddingRange ~= r.first! {
        r.insert(0x00, at: 0)
    }
    var s = Data(raw[rawLength...])
    if paddingRange ~= s.first! {
        s.insert(0x00, at: 0)
    }

    let signature = encode(data: r) + encode(data: s)

    let bound = target.bindMemory(to: UInt8.self, capacity: signature.count)
    for x in 0..<signature.count {
        bound [x] = signature [x]
    }

    sig?.pointee = bound
    sig_len?.pointee = signature.count

    return 0
}
