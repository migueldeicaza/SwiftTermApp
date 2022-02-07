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
    var readCallback: ((Channel, Data?, Data?)->())

    
    init (session: Session, channelHandle: OpaquePointer, readCallback: @escaping (Channel, Data?, Data?)->()) {
        self.channelHandle = channelHandle
        self.sessionActor = session.sessionActor
        self.session = session
        self.readCallback = readCallback
        buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        bufferError = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        libssh2_channel_set_blocking(channelHandle, 0)
    }
    
    deinit {
        dispatchPrecondition(condition: .onQueue(sshQueue))

        libssh2_channel_free(channelHandle)
    }

    // Equatable.func == 
    public static func == (lhs: Channel, rhs: Channel) -> Bool {
        lhs.channelHandle == rhs.channelHandle
    }
    

    public func setEnvironment (name: String, value: String) async {
        let _ = await sessionActor.channelSetEnv (self, name: name, value: value)
    }
    
    // Returns 0 on success, or a LIBSSH2 error otherwise, always retries operations, so EAGAIN is never returned
    public func requestPseudoTerminal (name: String, cols: Int, rows: Int) async -> Int32 {
        return await sessionActor.requestPseudoTerminal(self, name: name, cols: cols, rows: rows)
    }
    
    public func setTerminalSize (cols: Int, rows: Int, pixelWidth: Int, pixelHeight: Int) async {
        return await sessionActor.setTerminalSize(self, cols: cols, rows: rows, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }

    // Returns 0 on success, or a LIBSSH2 error otherwise, always retries operations, so EAGAIN is never returned
    public func processStartup (request: String, message: String?) async -> Int32 {
        return await sessionActor.processStartup(self, request: request, message: message)
    }
    
    public var receivedEOF: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(sshQueue))

            return libssh2_channel_eof(channelHandle) == 1
        }
    }
    
    // Invoked when there is some data received on the session, and we try to fetch it for the channel
    // if it is available, we dispatch it.
    func ping () {
        dispatchPrecondition(condition: .onQueue(sshQueue))
        // standard channel
        let streamId: Int32 = 0
        var ret, retError: Int
        
        ret = libssh2_channel_read_ex (channelHandle, streamId, buffer, bufferSize)
        retError = libssh2_channel_read_ex (channelHandle, SSH_EXTENDED_DATA_STDERR, bufferError, bufferSize)

        let data = ret >= 0 ? Data (bytesNoCopy: buffer, count: ret, deallocator: .none) : nil
        let error = retError >= 0 ? Data (bytesNoCopy: bufferError, count: retError, deallocator: .none) : nil
        
        if receivedEOF {
            session.unregister(channel: self)
        }
        if ret >= 0 || retError >= 0 {
            readCallback (self, data, error)
        } else {
            // Nothing read
        }
    }
    
    func close () {
        dispatchPrecondition(condition: .onQueue(sshQueue))

        while libssh2_channel_close(channelHandle) == LIBSSH2_ERROR_EAGAIN {
            // Wait
        }
    }
    
    /// Sends the provided data to the channel, and invokes the callback with the status code when doneaaaa
    func send (_ data: Data, callback: @escaping (Int)->()) {
        if data.count == 0 {
            return
        }
        sshQueue.async {
            data.withUnsafeBytes { (unsafeBytes) in
                let bytes = unsafeBytes.bindMemory(to: CChar.self).baseAddress!
                
                let ret = libssh2_channel_write_ex(self.channelHandle, 0, bytes, data.count)
                if ret < 0 {
                    print ("DEBUG libssh2_channel_write_ex result: \(libSsh2ErrorToString(error:Int32(ret)))")
                }
                
                callback (ret)
            }
        }
    }
    
    func exec (_ command: String) -> Int32 {
        dispatchPrecondition(condition: .onQueue(sshQueue))

        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_process_startup (channelHandle, "exec", 4, command, UInt32(command.utf8.count))
        } while ret == LIBSSH2_ERROR_EAGAIN
        return ret
    }
}
