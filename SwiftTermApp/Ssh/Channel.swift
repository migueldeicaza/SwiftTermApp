//
//  Channel.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 12/11/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
@_implementationOnly import CSSH
import CSwiftSH

/// Surfaces operations on channels
public class Channel: Equatable {
    var channelHandle: OpaquePointer
    weak var sessionActor: SessionActor!
    weak var session: Session!
    var buffer, bufferError: UnsafeMutablePointer<Int8>
    let bufferSize = 32*1024
    var sendQueue = DispatchQueue (label: "channelSend", qos: .userInitiated)
    var readCallback: ((Channel, Data?, Data?)async->())

    
    init (session: Session, channelHandle: OpaquePointer, readCallback: @escaping (Channel, Data?, Data?)async->()) {
        self.channelHandle = channelHandle
        self.sessionActor = session.sessionActor
        self.session = session
        self.readCallback = readCallback
        buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        bufferError = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        libssh2_channel_set_blocking(channelHandle, 0)
    }
    
    deinit {
        let s = sessionActor!
        let t = channelHandle
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
        get {
            return libssh2_channel_eof(channelHandle) == 1
        }
    }
    
    // Invoked when there is some data received on the session, and we try to fetch it for the channel
    // if it is available, we dispatch it.
    func ping () async {
        let pair = await sessionActor.ping(channel: self)
        
        if receivedEOF {
            session.unregister(channel: self)
        }
        if let channelData = pair {
            await readCallback (self, channelData.0, channelData.1)
        }
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
