//
//  DataModel.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/16/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

extension CHost {
    public var id: UUID {
        UUID ()
    }

    public var alias: String {
        sAlias ?? ""
    }
    
    public var hostname: String {
        sHostname ?? ""
    }
    
    public var background: String {
        sBackground ?? ""
    }
    
    public var backspaceAsControlH: Bool {
        sBackspaceAsControlH
    }
    
    public var port: Int {
        Int (sPort)
    }
    
    public var usePassword: Bool {
        sUsePassword
    }
    
    public var username: String {
        sUsername ?? ""
    }
    
//    public var password: String {
//        sPassword ?? ""
//    }
    
    public var hostKind: String {
        sHostKind ?? ""
    }
    
    public var environmentVariables: [String:String] {
        guard let arr = sEnvironmentVariables?.allObjects as? [CEnvironmentVariable] else {
            return [:]
        }
        var ret: [String:String] = [:]
        for x in arr {
            if let key = x.key, let value = x.value {
                ret [key] = value
            }
        }
        return ret
    }
    
    public var startupScripts: [String] {
        let scripts = sStartupScripts?.allObjects as? [CScripts] ?? []
        return scripts.compactMap { $0.script ?? nil }
    }
    
    public var sshKey: UUID? {
        sSshKey
    }
 
    public var style: String {
        sStyle ?? ""
    }
    
    public var lastUsed: Date {
        sLastUsed ?? Date.distantPast
    }
}
