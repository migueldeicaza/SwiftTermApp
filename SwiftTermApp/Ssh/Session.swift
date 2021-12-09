//
//  Session.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 12/8/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
import CSwiftSH
import Network

@_implementationOnly import CSSH

extension Data {
    public func dump() {
        let res = self.withUnsafeBytes { data -> String in
            var hexstr = String()
            var r = String()
            for i in data.bindMemory(to: UInt8.self) {
                hexstr += String(format: "%02X ", i)
            }
            return hexstr
        }
        print (res)
    }
}

class Session: CustomDebugStringConvertible {
    var handle: OpaquePointer!
    var socket: Int32
    
    // Turns the libssh2 abstract pointer (which is a pointer to the value passed) into a strong type
    static func getSession (from abstract: UnsafeRawPointer) -> Session {
        let ptr = abstract.bindMemory(to: UnsafeRawPointer.self, capacity: 1)
        return Unmanaged<Session>.fromOpaque(ptr.pointee).takeUnretainedValue()
    }

    typealias disconnectType = @convention(c) (UnsafeRawPointer, CInt,
                                               UnsafePointer<CChar>, CInt,
                                               UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void
    
    public init () {
        libssh2_init(0)
        socket = 0
        
        // TODO: this should be passUnretained
        let x = UnsafeMutableRawPointer(mutating: Unmanaged.passRetained(self).toOpaque())
        let inverse = Unmanaged<SocketSession>.fromOpaque(x).takeRetainedValue ()
        CFGetRetainCount(inverse)
        print ("Got \(x) and \(inverse)")
        handle = libssh2_session_init_ex(nil, nil, nil, x)
        let flags: Int32 = 0
        libssh2_trace(handle, flags)
        libssh2_trace_sethandler(handle, nil, { session, context, data, length in
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
        }
        libssh2_session_callback_set(handle, LIBSSH2_CALLBACK_DISCONNECT, unsafeBitCast(callback, to: UnsafeMutableRawPointer.self))
        // TODO: wish of mine: should set all the callbacjs, and handle every scenario
        setupCallbacks ()
    }
    
    var debugDescription: String {
        get { "<Invalid Session>" }
    }
    
    // Should setup the read/write callbacks
    public func setupCallbacks () {
    }
    
    func handshake () {
        libssh2_session_handshake(handle, socket)
    }
    
    public func getFingerprintBytes () -> [UInt8]? {
        guard let hashPointer = libssh2_hostkey_hash(handle, LIBSSH2_HOSTKEY_HASH_SHA256) else {
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
    
    func setupSshConnection () {
        Task {
            handshake()
            let res = String (cString: libssh2_session_banner_get(handle))
            print ("Got remote banner: \(res)")
            print ("Finger: \(getFingerprint ())")
        }
    }
    
    
}

// A session powered by sockets
class SocketSession: Session {
    var host: String
    var port: UInt16
    var connection: NWConnection
    var sendQueue: DispatchQueue
    
    public init (host: String, port: UInt16) {
        self.host = host
        self.port = port
        
        connection = NWConnection(host: NWEndpoint.Host (host), port: NWEndpoint.Port (integerLiteral: port), using: .tcp)
        sendQueue = DispatchQueue.global(qos: .userInitiated)
        super.init ()
        connection.stateUpdateHandler = connectionStateHandler
        connection.start (queue: DispatchQueue.main)
    }
    
    deinit{
        print ("not good")
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
            setupSshConnection ()
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
    
    static func send_callback(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt, abstract: UnsafeRawPointer) -> ssize_t {
        let session = SocketSession.getSocketSession(from: abstract)
        
        let connection = session.connection
        let data = Data (bytes: buffer, count: length)
        print ("Send On session: \(session), data: \(data.hexadecimalString())")
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: NWError? = nil
        connection.send (content: data, completion: .contentProcessed { error in
            sendError = error
            semaphore.signal()
        })
        semaphore.wait()
        return successOrError (sendError, n: data.count)
    }
    
    static func recv_callback(socket: libssh2_socket_t, buffer: UnsafeRawPointer, length: size_t, flags: CInt, abstract: UnsafeRawPointer) -> ssize_t {
        let session = SocketSession.getSocketSession(from: abstract)
        let connection = session.connection
        print ("Recv On session: \(session)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var recvError: NWError? = nil
        var count = 0
        connection.receive(minimumIncompleteLength: 0, maximumLength: length) { data, context, isComplete, error in
            recvError = error
            if let data = data {
                let x = UnsafeMutablePointer<UInt8> (OpaquePointer (buffer))
                
                
                data.copyBytes(to: x, count: data.count)
                print ("Received: \(data.count) \(data.hexadecimalString())")
                count = data.count
            }
            semaphore.signal ()
        }
        semaphore.wait ()
        return successOrError(recvError, n: count)
    }
    
    typealias socketCbType = @convention(c) (libssh2_socket_t, UnsafeRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
    
    public override func setupCallbacks () {
        let send: socketCbType = { socket, buffer, length, flags, abstract in
            SocketSession.send_callback(socket: socket, buffer: buffer, length: length, flags: flags, abstract: abstract)
        }
        
        let recv: socketCbType = { socket, buffer, length, flags, abstract in
            SocketSession.recv_callback(socket: socket, buffer: buffer, length: length, flags: flags, abstract: abstract)
        }
        libssh2_session_callback_set(handle, LIBSSH2_CALLBACK_SEND, unsafeBitCast(send, to: UnsafeMutableRawPointer.self))
        libssh2_session_callback_set(handle, LIBSSH2_CALLBACK_RECV, unsafeBitCast(recv, to: UnsafeMutableRawPointer.self))
    }
}

class ProxySession: Session {
    public override init ()
    {
        super.init ()
    }
    
    public override func setupCallbacks () {
    }
}
