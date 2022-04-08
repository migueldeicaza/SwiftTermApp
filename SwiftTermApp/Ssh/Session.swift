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
import Network
import CryptoKit

@_implementationOnly import CSSH

protocol SessionDelegate: AnyObject {
    /// Called to authenticate the user on the network queue, once the
    /// connection has been established.
    /// - Parameter session: identifies the session that this callback is for
    /// - Returns: nil on success, or a human-readable description as a string on error
    func authenticate (session: Session) async -> String?
    
    /// Called if we failed to login on the network queue
    /// - Parameter session: identifies the session that this callback is for
    func loginFailed (session: Session, details: String)
    
    /// Called when we are authenticated on the network queue, and channels can be opened
    /// - Parameter session: identifies the session that this callback is for
    func loggedIn (session: Session) async
    
    /// Called on the sshQueue, this message is invoked in response to receiving an `SSH_MSG_DEBUG` message
    /// described in https://datatracker.ietf.org/doc/html/rfc4253
    func debug (session: Session, alwaysDisplay: Bool, message: Data, language: Data)
    
    /// Invoked when the remote end has been disconnected - TODO need to wire this up
    func remoteEndDisconnected (session: Session)
    
    /// Invoked to log connection startup information
    func logConnection (_ msg: String)
}

/// We execute all calls to libssh2 on the ssh queue.
var sshQueue: DispatchQueue = DispatchQueue.init(label: "ssh-queue", qos: .userInitiated)

/// Session represents a libssh2 session, callbacks for assorted operations in the session
/// are done via the SessionDelegate protocol that is passed as a parameter to the
/// constructor.   Each method in the delegate protocol describes in which queue the method
/// will be invoked.
///
/// Once the network connection has been established, the `sessionDelegate.authenticate` method
/// will be invoked, and that method should attempt to authenticate based on the list of available
/// authentication methods surfaced by `userAuthenticationList`, and then calling into one or more
/// of the  `userAuth` methods in the session class.
///
/// Depending on the authentication, the callbacks `loginFailed` or `loggedIn` will be invoked.
///
/// Upon success, a channel can be created, with `openChannel`, or `openSessionChannel`, or the
/// convenience methods `run`.
///
/// Because libssh2 does not have a way of notifying if a specific channel has data available once it
/// is received by the session, this implenentation currently notifies all channels that they should poll
/// for data.
class Session: CustomDebugStringConvertible {
    // Our actor that serializes access to libssh in a per-session basis
    var sessionActor: SessionActor
    
    var channelsLock = NSLock ()
    
    // Where we post interesting events about this session
    weak var delegate: SessionDelegate!
    
    // Turns the libssh2 abstract pointer (which is a pointer to the value passed) into a strong type
    static func getSession (from abstract: UnsafeRawPointer) -> Session {
        let ptr = abstract.bindMemory(to: UnsafeRawPointer.self, capacity: 1)
        return Unmanaged<Session>.fromOpaque(ptr.pointee).takeUnretainedValue()
    }

    public init (delegate: SessionDelegate, send: @escaping socketCbType, recv: @escaping socketCbType, disconnect: @escaping disconnectCbType, debug: @escaping debugCbType) {
        self.delegate = delegate
        
        channelsLock = NSLock ()
        
        // Init this first, we will wipe it out soon enough
        sessionActor = SessionActor (fakeSetup: true)
        let opaqueHandle = UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque())
        sessionActor = SessionActor (send: send, recv: recv, disconnect: disconnect, debug: debug, opaque: opaqueHandle)
    }
    
    func log (_ msg: String) {
        delegate.logConnection(msg)
    }

    var debugDescription: String {
        get { "<Invalid session: use a subclass>" }
    }
    
    // Should setup the read/write callbacks
    public func setupCallbacks () {
    }
    
    /// Gets the host and key for the host.
    /// The type is one of:
    ///   * LIBSSH2_HOSTKEY_TYPE_UNKNOWN
    ///   * LIBSSH2_HOSTKEY_TYPE_RSA
    ///   * LIBSSH2_HOSTKEY_TYPE_DSS
    ///   * LIBSSH2_HOSTKEY_TYPE_ECDSA_256
    ///   * LIBSSH2_HOSTKEY_TYPE_ECDSA_384
    ///   * LIBSSH2_HOSTKEY_TYPE_ECDSA_521
    ///   * LIBSSH2_HOSTKEY_TYPE_ED25519
    /// - Returns: tuple with the key as an array of bytes and the type.
    /// Returns the key and type for the host.  The key is one of
    public func hostKey () async -> (key: [Int8], type: Int32)? {
        return await sessionActor.hostKey ()
    }

    /// Performs the SSH session handshake
    public func handshake () async -> Int32 {
        return await sessionActor.handshake ()
    }
    
    /// Returns an array of authentication methods available for the specified user
    public func userAuthenticationList (username: String) async -> String {
        return await sessionActor.userAuthenticationList (username: username)
    }
    
    /// Returns the hostkey SHA256 hash from the session as an array of bytes
    public func getFingerprintBytes () async -> [UInt8]? {
        return await sessionActor.getFingerprintBytes ()
    }
    
    /// Returns the hostkey SHA256 hash from the session as a string with the prefix "SHA256:" followed by the base64-encoded hash.
    public func getFingerprint () async -> String? {
        guard let bytes = await getFingerprintBytes() else {
            return nil
        }
        let d = Data (bytes)
        return "SHA256:" + d.base64EncodedString()
    }
    
    var timeout: Date?
    public private(set) var banner: String = ""
    
    func setupSshConnection () async
    {
        log ("SSH: sending handshake")
        let handshakeStatus = await handshake()
        if handshakeStatus != 0 {
            
            log ("SSH: handshake error, code: \(libSsh2ErrorToString(error: handshakeStatus)) \(handshakeStatus)")
            // There was an error
            // TODO: handle this one
        }
        banner = await sessionActor.getBanner ()
        let failureReason = await delegate.authenticate(session: self)
        if let err = failureReason {
            log ("SSH Authentication result: \(err)")
        }
        
        if await authenticated {
            log ("SSH authenticated")
            await delegate.loggedIn(session: self)
        } else {
            log ("SSH loginFailed")
            delegate.loginFailed (session: self, details: failureReason ?? "Internal error: authentication claims it worked, but libssh2 state indicates it is not authenticated")
        }
    }
    
    /// Determines if the session has been authenticated
    public var authenticated: Bool {
        get async {
            return await sessionActor.authenticated
        }
    }
    
    /// Performs a username/password authentication
    /// - Returns: nil on success, or a user-visible description on error
    public func userAuthPassword (username: String, password: String) async -> String? {
        return await sessionActor.userAuthPassword (username: username, password: password)
    }
    
    var promptFunc: ((String)->String)?
    
    /// Performs an interactive user authentication for the specified username
    /// - Parameter prompt: method to invoke to present the prompt to the user
    /// - Returns: nil on success, or a user-visible description on error
    public func userAuthKeyboardInteractive (username: String, prompt: @escaping (String)->String) async -> String? {
        promptFunc = prompt
        return await sessionActor.userAuthKeyboardInteractive(username: username)
    }
    
    /// Authenticates using the provided public/private key pairs
    /// - Parameters:
    ///  - username: Remote user name to authenticate as
    ///  - passPhrase: passphrase to use to decode the private key file
    ///  - publicKey: Contents of the public key
    ///  - privateKey: contents of the private key
    /// - Returns: nil on success, or a user-visible description on error
    public func userAuthPublicKeyFromMemory (username: String, passPhrase: String, publicKey: String, privateKey: String) async -> String? {
        return await sessionActor.userAuthPublicKeyFromMemory (username: username, passPhrase: passPhrase, publicKey: publicKey, privateKey: privateKey)
    }
    
    /// Authenticates the session using a callback method
    /// - Parameters:
    ///  - username: Remote user name to authenticate as
    ///  - publicKey: Contents of the public key
    ///  - signCallback: method that receives a Data to be signed, and returns the signed data on success, nil on error
    /// - Returns:nil on success, or a user-visible description on error
    public func userAuthWithCallback (username: String, publicKey: Data, signCallback: @escaping (Data)->Data?) async -> String? {
        return await sessionActor.userAuthWithCallback(username: username, publicKey: publicKey, signCallback: signCallback)
    }
    
    var channels: [Channel] = []
    
    /// Opens a new channel with a specified type (session, direct-tcpip, or tcpip-forward)
    /// - Parameters:
    ///  - type: session, direct-tcpip, or tcpip-forward
    ///  - windowSize: Maximum amount of unacknowledged data remote host is allowed to send before receiving an SSH_MSG_CHANNEL_WINDOW_ADJUST packet, defaults to 2 megabytes
    ///  - packetSize: Maximum number of bytes remote host is allowed to send in a single SSH_MSG_CHANNEL_DATA or SSG_MSG_CHANNEL_EXTENDED_DATA packet, defaults to 32k
    ///  - readCallback: method that is invoked when new data is available on the channel, it receives the channel source as a parameter, and two Data? parameters,
    ///   one for standard output, and one for standard error.
    public func openChannel (type: String,
                             windowSize: CUnsignedInt = 2*1024*1024,
                             packetSize: CUnsignedInt = 32768,
                             readCallback: @escaping (Channel, Data?, Data?)async->()) async -> Channel? {
        guard let channelHandle = await sessionActor.openChannel(type: type, windowSize: windowSize, packetSize: packetSize, readCallback: readCallback) else {
            return nil
        }
        return Channel (session: self, channelHandle: channelHandle, readCallback: readCallback, type: type)

    }
    
    /// Opens a new session channel with the defaults, and with the specified LANG environment variable set
    /// - Parameters:
    ///  - lang: The desired value for the LANG environment variable to be set on the remote end
    ///  - readCallback: method that is invoked when new data is available on the channel, it receives the channel source as a parameter, and two Data? parameters,
    ///   one for standard output, and one for standard error.
    public func openSessionChannel (lang: String, readCallback: @escaping (Channel, Data?, Data?)async->()) async -> Channel? {
        if let channel = await openChannel(type: "session", readCallback: readCallback) {
            await channel.setEnvironment(name: "LANG", value: lang)
            
            return channel
        }
        return nil
    }
    
    /// Runs a command on the remote server using the specified language, and delivers the data to the callback
    /// - Parameters:
    ///  - command: the command to execute on the remote server
    ///  - lang: The desired value for the LANG environment variable to be set on the remote end
    ///  - readCallback: method that is invoked when new data is available on the channel, it receives the channel source as a parameter, and two Data? parameters,
    ///   one for standard output, and one for standard error.
    public func runAsync (command: String, lang: String, readCallback: @escaping (Channel, Data?, Data?)async->()) async -> Channel? {
        if let channel = await openSessionChannel(lang: lang, readCallback: readCallback) {
            let status = await channel.exec (command)
            if status == 0 {
                activate(channel: channel)
                return channel
            }
            await channel.close ()
        }
        return nil
    }

    /// Runs a command on the remote server using the specified language, and delivers the data to the callback as strings
    /// - Parameters:
    ///  - command: the command to execute on the remote server
    ///  - lang: The desired value for the LANG environment variable to be set on the remote end
    ///  - resultCallback: method that is invoked when the command completes containing the stdout and stderr results as string parameters
    ///
    ///  This method will only return after the resultCallback is invoked
    public func runSimple<T> (command: String, lang: String, resultCallback: @escaping (String?, String?)async->(T)) async -> T {
        return await withCheckedContinuation { c in
            Task {
                var stdout = Data()
                var stderr = Data()
                
                // One time, I got an exception from `c.resume` below being invoked twice, to avoid
                // a crash, I catch this for now, but should find out why this happens.   Happened
                // on first login.
                var usedHardeningUntilBugTracked = false
                
                let _ = await runAsync(command: command, lang: lang) { channel, out, err in
                    if let gotOut = out {
                        stdout.append(gotOut)
                    }
                    if let gotErr = err {
                        stderr.append(gotErr)
                    }
                    if await channel.receivedEOF {
                        let s = String (bytes: stdout, encoding: .utf8)
                        let e = String (bytes: stderr, encoding: .utf8)

                        let r = await resultCallback (s, e)
                        
                        print ("Resuming for command \(command)")
                        if !usedHardeningUntilBugTracked {
                            c.resume(returning: r)
                        }
                        usedHardeningUntilBugTracked = true
                    }
                }
            }
        }
    }

    /// Opens a new channel with a specified type (session, direct-tcpip, or tcpip-forward)
    /// - Parameters:
    ///  - type: session, direct-tcpip, or tcpip-forward
    ///  - windowSize: Maximum amount of unacknowledged data remote host is allowed to send before receiving an SSH_MSG_CHANNEL_WINDOW_ADJUST packet, defaults to 2 megabytes
    ///  - packetSize: Maximum number of bytes remote host is allowed to send in a single SSH_MSG_CHANNEL_DATA or SSG_MSG_CHANNEL_EXTENDED_DATA packet, defaults to 32k
    ///  - readCallback: method that is invoked when new data is available on the channel, it receives the channel source as a parameter, and two Data? parameters,
    ///   one for standard output, and one for standard error.
    public func openSftp () async -> SFTP? {
        guard let sftpHandle = await sessionActor.openSftp () else {
            return nil
        }
        return SFTP (session: self, sftpHandle: sftpHandle)
    }
    
    /// Invoke this method to activate a channel - this will ensure that the channel will be notified of new data availability
    func activate (channel: Channel) {
        channelsLock.lock()
        channels.append(channel)
        channelsLock.unlock()
    }
    
    /// Unregisters the channel from the session, invoke this when the channel has closed, so that their callbacks are no longer invoked
    func unregister (channel: Channel) {
        channelsLock.lock()
        if let index = channels.firstIndex(of: channel) {
            print ("Channel removed")
            channels.remove (at: index)
        }
        channelsLock.unlock()
    }
    
    /// Creates an instance of the libssh2-level list of known hosts.
    public func makeKnownHost () async -> LibsshKnownHost? {
        return await sessionActor.makeKnownHost()
    }

    public func shutdown () {
        
    }

    /// Disconnects the session from the remote end, you can specifiy a reason, as well as a description that is sent to the remote server
    /// - Parameters:
    ///  - reason: the reason for the disconnection
    ///  - description: a human-readable descriptioin that will be sent to the remote end at close time.
    public func disconnect (reason: Int32 = SSH_DISCONNECT_BY_APPLICATION, description: String) async {
        await sessionActor.disconnect (reason: reason, description: description)
    }

}

/// A session powered by an NWConnection socket
///
/// This class is a concrete implementation that uses NWConnection to establish the connection, as
/// opposed to other versions that might be proxies or wrappers to enable session restoration.
///
/// The NWConnection read loop will pull data on a dedicated network queue and place accumulate the
/// results in buffers that are later pulled out from the SSH queue.
class SocketSession: Session {
    var host: String
    var port: UInt16
    var connection: NWConnection
    static var networkQueue: DispatchQueue = DispatchQueue.global (qos: .userInitiated)
    
    /// Creates a SocketSession to the specified host and port, using the provided delegate
    public init (host: String, port: UInt16, delegate: SessionDelegate) {
        self.host = host
        self.port = port
        
        let send: socketCbType = { socket, buffer, length, flags, abstract in
            SocketSession.send_callback(socket: socket, buffer: buffer, length: length, flags: flags, abstract: abstract)
        }
        
        let recv: socketCbType = { socket, buffer, length, flags, abstract in
            return SocketSession.recv_callback(socket: socket, buffer: buffer, length: length, flags: flags, abstract: abstract)
        }
        let disconnect: disconnectCbType = { sess, reason, message, messageLen, language, languageLen, abstract in
            let session = Session.getSession(from: abstract)
            
            Task {
                await session.disconnect(reason: SSH_DISCONNECT_CONNECTION_LOST, description: "")
            }
        }

        let debug: debugCbType = { session, alwaysDisplay, messagePtr, messageLen, languagePtr, languageLen, abstract in
            let msg = Data (bytes: messagePtr, count: Int (messageLen))
            let lang = Data (bytes: languagePtr, count: Int (languageLen))
            
            let session = SocketSession.getSocketSession(from: abstract)
            session.delegate.debug(session: session, alwaysDisplay: alwaysDisplay != 0, message: msg, language: lang)
        }
        delegate.logConnection("NWConnection to \(host):\(port)")
        connection = NWConnection(host: NWEndpoint.Host (host), port: NWEndpoint.Port (integerLiteral: port), using: .tcp)
        super.init(delegate: delegate, send: send, recv: recv, disconnect: disconnect, debug: debug)
        
        connection.stateUpdateHandler = connectionStateHandler
        connection.start (queue: SocketSession.networkQueue)
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
    
    // This is where the network callback will store incoming data, that is pulled out from the
    // the _recv callback methods
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
            
            // TODO: maybe we do not need PingChannels, we can merge with pingtasks?
            sshQueue.async {
                self.pingChannels ()
            }
            Task { await self.sessionActor.pingTasks() }
            
            if restart {
                self.startIO()
            } else {
                
            }
        }
    }
    
    public override func shutdown () {
        connection.cancel()
    }
    
    // Since libssh2 does not provide a callback/completion system per channel, we inform
    // all registered channels that new data is available, so they can pull and process.
    func pingChannels () {
        Task {
            var copy: [Channel] = []
            for channel in channels {
                if await channel.ping () {
                    copy.append (channel)
                }
            }
            channelsLock.lock()
            channels = copy
            channelsLock.unlock()
        }
    }
       
    func connectionStateHandler (state: NWConnection.State) {
        switch state {
        case .setup:
            log ("NWConnection state .setup")
        case .waiting(let detail):
            log ("NWConnection state: .waiting (\(detail))")
        case .preparing:
            log ("NWConnection state .preparing")
        case .ready:
            log ("NWConnection state .ready")
            startIO()
            Task {
                await setupSshConnection ()
            }
        case .failed(let details):
            log ("NWConnection state .failed: \(details)n")
            delegate.remoteEndDisconnected(session: self)
        case .cancelled:
            log ("NWConnection state .canceled")
        @unknown default:
            log ("NWConnection state is unknown")
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
  
    // Callback invoked by libssh2 to receive data from our connection
    static func recv_callback(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt, abstract: UnsafeRawPointer) -> ssize_t {
        let session = SocketSession.getSocketSession(from: abstract)

        let x = UnsafeMutablePointer<UInt8> (OpaquePointer (buffer))
        var consumedBytes = 0
        var wasError: NWError? = nil
        
        while true {
            session.bufferLock.lock ()
            consumedBytes = min (length, session.buffer.count)
            session.buffer.copyBytes(to: x, count: consumedBytes)
            session.buffer = session.buffer.dropFirst(consumedBytes)
            wasError = session.buffer.count == 0 && session.bufferError != nil ? session.bufferError : nil
            session.bufferLock.unlock()
            
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
            return Int (-EAGAIN)
        }
        let ret = successOrError(wasError, n: consumedBytes)
        return ret
    }
        
    public override func disconnect (reason: Int32 = SSH_DISCONNECT_BY_APPLICATION, description: String) async {
        await super.disconnect(reason: reason, description: description)
        connection.forceCancel()
    }
}

class ProxySession: Session {
    public init (delegate: SessionDelegate)
    {
        abort ()
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
