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
public class Channel {
    var channelHandle: OpaquePointer
    weak var session: Session!
    var buffer, bufferError: UnsafeMutablePointer<Int8>
    let bufferSize = 32*1024
    var sendQueue = DispatchQueue (label: "channelSend", qos: .userInitiated)
    var readCallback: ((Channel, Data?, Data?)->())

    init (session: Session, channelHandle: OpaquePointer, readCallback: @escaping (Channel, Data?, Data?)->()) {
        self.channelHandle = channelHandle
        self.session = session
        self.readCallback = readCallback
        buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        bufferError = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        libssh2_channel_set_blocking(channelHandle, 0)
    }
    
    deinit {
        libssh2_channel_free(channelHandle)
    }
    
    public func setEnvironment (name: String, value: String) {
        var ret: CInt = 0
        
        repeat {
            ret = libssh2_channel_setenv_ex (channelHandle, name, UInt32(name.utf8.count), value, UInt32(value.utf8.count))
        } while ret == LIBSSH2_ERROR_EAGAIN
    }
    
    // Returns 0 on success, or a LIBSSH2 error otherwise, always retries operations, so EAGAIN is never returned
    public func requestPseudoTerminal (name: String, cols: Int, rows: Int) -> Int32 {
        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_request_pty_ex(channelHandle, name, UInt32(name.utf8.count), nil, 0, Int32(cols), Int32(rows), LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
        } while ret == LIBSSH2_ERROR_EAGAIN
        return ret
    }
    
    public func setTerminalSize (cols: Int, rows: Int, pixelWidth: Int, pixelHeight: Int) {
        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_request_pty_size_ex(channelHandle, Int32(cols), Int32(rows), Int32(pixelWidth), Int32(pixelHeight))
        } while ret == LIBSSH2_ERROR_EAGAIN
    }

    // Returns 0 on success, or a LIBSSH2 error otherwise, always retries operations, so EAGAIN is never returned
    public func processStartup (request: String, message: String?) -> Int32 {
        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_process_startup (channelHandle, request, UInt32(request.utf8.count), message, message == nil ? 0 : UInt32(message!.utf8.count))
        } while ret == LIBSSH2_ERROR_EAGAIN
        return ret
    }
    
    public var receivedEOF: Bool {
        get {
            libssh2_channel_eof(channelHandle) == 1
        }
    }
    
    // Invoked when there is some data received on the session, and we try to fetch it for the channel
    // if it is available, we dispatch it.
    func ping () {
        // standard channel
        let streamId: Int32 = 0
        var ret, retError: Int
        
        ret = libssh2_channel_read_ex (channelHandle, streamId, buffer, bufferSize)
        retError = libssh2_channel_read_ex (channelHandle, SSH_EXTENDED_DATA_STDERR, bufferError, bufferSize)

        let data = ret >= 0 ? Data (bytesNoCopy: buffer, count: ret, deallocator: .none) : nil
        let error = retError >= 0 ? Data (bytesNoCopy: bufferError, count: retError, deallocator: .none) : nil
        
        readCallback (self, data, error)
    }
    
    /// Sends the provided data to the channel, and invokes the callback on the main thread upon completion
    func send (_ data: Data, callback: @escaping (Int)->()) {
        if data.count == 0 {
            return
        }
        data.withUnsafeBytes { (unsafeBytes) in
            let bytes = unsafeBytes.bindMemory(to: CChar.self).baseAddress!
            let ret = libssh2_channel_write_ex(self.channelHandle, 0, bytes, data.count)
            if ret < 0 {
                print ("DEBUG Got: \(libSsh2ErrorToString(error:Int32(ret)))")
            }
            callback (ret)
        }
    }
}
