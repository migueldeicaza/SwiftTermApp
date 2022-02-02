//
//  SFTP.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 2/1/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
@_implementationOnly import CSSH
import CSwiftSH

public class SFTP {
    var sftpHandle: OpaquePointer
    weak var session: Session!
    
    init (session: Session, sftpHandle: OpaquePointer) {
        dispatchPrecondition(condition: .onQueue(sshQueue))

        self.sftpHandle = sftpHandle
        self.session = session
    }
    
    deinit {
        dispatchPrecondition(condition: .onQueue(sshQueue))

        libssh2_sftp_shutdown (sftpHandle)
    }

    func stat (path: String) -> LIBSSH2_SFTP_ATTRIBUTES? {
        dispatchPrecondition(condition: .onQueue(sshQueue))

        var ret: CInt = 0
        var attr: LIBSSH2_SFTP_ATTRIBUTES = LIBSSH2_SFTP_ATTRIBUTES()
        let pc = UInt32 (path.utf8.count)
        
        repeat {
            ret = libssh2_sftp_stat_ex(sftpHandle, path, pc, LIBSSH2_SFTP_STAT, &attr)
        } while ret == LIBSSH2_ERROR_EAGAIN
        return ret == 0 ? attr : nil
    }

    func llOpen (path: String, flags: UInt, file: Bool) -> OpaquePointer? {
        dispatchPrecondition(condition: .onQueue(sshQueue))
        let pc = UInt32 (path.utf8.count)
        var handle: OpaquePointer!
        repeat {
            handle = libssh2_sftp_open_ex(sftpHandle, path, pc, flags, 0, file ? LIBSSH2_SFTP_OPENFILE : LIBSSH2_SFTP_OPENDIR)
        } while handle == nil && libssh2_session_last_errno(session!.sessionHandle) == LIBSSH2_ERROR_EAGAIN
        return handle
    }
    
    func readFile (path: String, limit: Int) -> [Int8]? {
        guard let f = llOpen (path: path, flags: UInt (LIBSSH2_FXF_READ), file: true) else {
            return nil
        }
        var buffer: [Int8] = []
        let size = 8192
        var llbuffer = Array<Int8>.init(repeating: 0, count: size)
        var ret: Int = 0
        var left = limit
        repeat {
            ret = libssh2_sftp_read(f, &llbuffer, min (size, left))
            if ret > 0 {
                left -= ret
                buffer.append(contentsOf: llbuffer [0..<ret])
            }
            if ret == 0 {
                break
            }
        } while ret == LIBSSH2_ERROR_EAGAIN || left > 0
        ret = 0
        repeat {
            ret = Int (libssh2_sftp_close_handle(f))
        } while ret == LIBSSH2_ERROR_EAGAIN
        return buffer
    }
    
    func readFileAsString (path: String, limit: Int) -> String? {
        if let bytes = readFile (path: path, limit: limit) {
            let d = Data (bytes: bytes, count: bytes.count)
            return String (bytes: d, encoding: .utf8)
        }
        return nil
    }

}
