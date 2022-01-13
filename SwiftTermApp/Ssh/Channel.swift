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

public class Channel {
    var channelHandle: OpaquePointer
    weak var session: Session!
    var buffer, bufferError: UnsafeMutablePointer<Int8>
    let bufferSize = 32*1024
    var sendQueue = DispatchQueue (label: "channelSend", qos: .userInitiated)
    
    init (session: Session, channelHandle: OpaquePointer) {
        self.channelHandle = channelHandle
        self.session = session
        
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
    
    // Returns true on success, false on failure
    public func requestPseudoTerminal (name: String, cols: Int, rows: Int) -> Bool {
        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_request_pty_ex(channelHandle, name, UInt32(name.utf8.count), nil, 0, Int32(cols), Int32(rows), LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_HEIGHT_PX)
        } while ret == LIBSSH2_ERROR_EAGAIN
        return ret == 0
    }
    
    public func setTerminalSize (cols: Int, rows: Int, pixelWidth: Int, pixelHeight: Int) {
        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_request_pty_size_ex(channelHandle, Int32(cols), Int32(rows), Int32(pixelWidth), Int32(pixelHeight))
        } while ret == LIBSSH2_ERROR_EAGAIN
    }

    // Returns true on success, false on failure
    public func processStartup (request: String, message: String?) -> Bool {
        var ret: Int32 = 0
        repeat {
            ret = libssh2_channel_process_startup (channelHandle, request, UInt32(request.utf8.count), message, message == nil ? 0 : UInt32(message!.utf8.count))
        } while ret == LIBSSH2_ERROR_EAGAIN
        return ret == 0
    }
    
    public var receivedEOF: Bool {
        get {
            libssh2_channel_eof(channelHandle) == 1
        }
    }
    
    var readCallback: ((Channel, Data?, Data?)->())?

    ///
    /// - Parameter readCallback: a callback to be invoked on the main thread when the data is available
    /// the stdout and the stderr as Data? if the data is available, nil otherwise.   This is invoked on a background thread
    public func setupIO (readCallback: @escaping (Channel, Data?, Data?)->()) {
        libssh2_channel_set_blocking(channelHandle, 0)
        self.readCallback = readCallback
    }
    
    // Invoked when there is some data received on the session, and we try to fetch it for the channel
    // if it is available, we dispatch it.
    func ping () {
        // standard channel
        let streamId: Int32 = 0
        var ret, retError: Int
        
        // We only perform reads once setupIO has been called, and readcallback has been configured
        guard let readCallback = readCallback else {
            return
        }
        ret = libssh2_channel_read_ex (channelHandle, streamId, buffer, bufferSize)
        retError = libssh2_channel_read_ex (channelHandle, SSH_EXTENDED_DATA_STDERR, bufferError, bufferSize)

        let data = ret >= 0 ? Data (bytesNoCopy: buffer, count: ret, deallocator: .none) : nil
        let error = retError >= 0 ? Data (bytesNoCopy: bufferError, count: retError, deallocator: .none) : nil
        
        readCallback (self, data, error)
    }
    
    func send (_ data: Data, callback: @escaping (Int)->()) {
        if data.count == 0 {
            return
        }
        sendQueue.async {
            
            data.withUnsafeBytes { (unsafeBytes) in
                let bytes = unsafeBytes.bindMemory(to: CChar.self).baseAddress!
                let ret = libssh2_channel_write_ex(self.channelHandle, 0, bytes, data.count)
                DispatchQueue.main.async {
                    callback (ret)
                }
            }
        }
    }
}
