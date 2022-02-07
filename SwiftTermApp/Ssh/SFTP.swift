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
        self.sftpHandle = sftpHandle
        self.session = session
    }
    
    deinit {
        Task { await session.sessionActor.sftpShutdown (sftpHandle) }
    }

    func stat (path: String) -> LIBSSH2_SFTP_ATTRIBUTES? {
        session.sessionActor.sftpStat (self, path: path)
    }

    func llOpen (path: String, flags: UInt, file: Bool) async -> OpaquePointer? {
        await session.sessionActor.sftpLlOpen (self, path: path, flags: flags, file: file)
    }
    
    func readFile (path: String, limit: Int) async -> [Int8]? {
        await session.sessionActor.sftpReadFile (self, path: path, limit: limit)
    }
    
    func readFileAsString (path: String, limit: Int) async -> String? {
        if let bytes = await readFile (path: path, limit: limit) {
            let d = Data (bytes: bytes, count: bytes.count)
            return String (bytes: d, encoding: .utf8)
        }
        return nil
    }

}
