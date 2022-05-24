//
//  Channel.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 12/11/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
@_implementationOnly import CSSH

/// Surfaces operations on channels, channels need to be activated on the session to receive data
public class Channel: Equatable {
    static var serial = 0
    static var channelLock = NSLock ()
    var channelHandle: OpaquePointer
    weak var sessionActor: SessionActor!
    weak var session: Session!
    var buffer, bufferError: UnsafeMutablePointer<Int8>
    let bufferSize = 32*1024
    var sendQueue = DispatchQueue (label: "channelSend", qos: .userInitiated)
    var readCallback: ((Channel, Data?, Data?, Bool)async->())
    var type: String
    var id: Int
    
    /// - Parameters:
    ///  - readCallback: this callback is invoked when new data is received from the connection, and it
    ///   contains the channel were the data was received, the stdout, stderr and an indicator whether this
    ///   has reached the end (eof)
    init (session: Session, channelHandle: OpaquePointer, readCallback: @escaping (Channel, Data?, Data?, Bool)async->(), type: String) {
        Channel.channelLock.lock ()
        Channel.serial += 1
        id = Channel.serial
        Channel.channelLock.unlock ()
        
        self.channelHandle = channelHandle
        self.sessionActor = session.sessionActor
        self.session = session
        self.readCallback = readCallback
        self.type = type
        buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        bufferError = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        libssh2_channel_set_blocking(channelHandle, 0)
    }
    
    deinit {
        let s = sessionActor!
        let t = channelHandle
        buffer.deallocate()
        bufferError.deallocate()
        Task {
            await s.free (channelHandle: t)
        }
    }

    // Equatable.func == 
    public static func == (lhs: Channel, rhs: Channel) -> Bool {
        lhs.channelHandle == rhs.channelHandle
    }
    
    public func setEnvironment (name: String, value: String) async {
        let _ = await sessionActor.setEnv (channel: self, name: name, value: value)
    }
    
    // Returns 0 on success, or a LIBSSH2 error otherwise, always retries operations, so EAGAIN is never returned
    public func requestPseudoTerminal (name: String, cols: Int, rows: Int) async -> Int32 {
        return await sessionActor.requestPseudoTerminal(channel: self, name: name, cols: cols, rows: rows)
    }
    
    public func setTerminalSize (cols: Int, rows: Int, pixelWidth: Int, pixelHeight: Int) async {
        return await sessionActor.setTerminalSize(channel: self, cols: cols, rows: rows, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }

    // Returns 0 on success, or a LIBSSH2 error otherwise, always retries operations, so EAGAIN is never returned
    public func processStartup (request: String, message: String?) async -> Int32 {
        return await sessionActor.processStartup(channel: self, request: request, message: message)
    }
    
    public var receivedEOF: Bool {
        get async {
            return await sessionActor.receivedEof (channel: self)
        }
    }

    // Invoked when there is some data received on the session, and we try to fetch it for the channel
    // if it is available, we dispatch it.   Returns true if the channel is still active
    func ping () async -> Bool {
        var eof: Bool = true
        let pair = await sessionActor.ping(channel: self, eofDetected: &eof)
        
        if let channelData = pair {
            await readCallback (self, channelData.0, channelData.1, eof)
        }
        return !eof
    }
    
    func close () async {
        await sessionActor.close (channel: self)
    }
    
    /// Sends the provided data to the channel, and invokes the callback with the status code when doneaaaa
    func send (_ data: Data, callback: @escaping (Int)->()) async {
        await sessionActor.send (channel: self, data: data, callback: callback)
    }
    
    func exec (_ command: String) async -> Int32 {
        return await sessionActor.exec (channel: self, command: command)
    }
}
