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
    
    init (session: Session, channelHandle: OpaquePointer) {
        self.channelHandle = channelHandle
        self.session = session
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
    
    public func setupIO () {
        
    }
    

}
