//
//  DataModel.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/16/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

extension Host {
    public var id: UUID {
        UUID ()
    }

    public var alias: String {
        get { sAlias ?? "" }
        set { sAlias = newValue }
    }
    
    public var hostname: String {
        get { sHostname ?? "" }
        set { sHostname = newValue }
    }
    
    public var background: String {
        get { sBackground ?? "" }
        set { sBackground = newValue }
    }
    
    public var backspaceAsControlH: Bool {
        get { sBackspaceAsControlH }
        set { sBackspaceAsControlH = newValue }
    }
    
    public var port: Int {
        get { Int (sPort) }
        set { sPort = Int64 (newValue) }
    }
    
    public var usePassword: Bool {
        get { sUsePassword }
        set { sUsePassword = newValue }
    }
    
    public var username: String {
        get { sUsername ?? "" }
        set { sUsername = newValue }
    }
    
    public var password: String {
        get { "" }
        set { }
    }
    
    public var hostKind: String {
        get { sHostKind ?? "" }
        set { sHostKind = newValue }
    }
    
    public var reconnectType: String {
        get { sReconnectType ?? "" }
        set { sReconnectType = newValue }
    }
    
    public var environmentVariables: [String:String] {
        get {
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
        set {
            // TODO
            abort ()
        }
    }
    
    public var startupScripts: [String] {
        get {
            let scripts = sStartupScripts?.allObjects as? [CScripts] ?? []
            return scripts.compactMap { $0.script ?? nil }
        }
        set {
            abort ()
        }
    }
    
    public var sshKey: UUID? {
        get { sSshKey }
        set { sSshKey = newValue }
    }
 
    public var style: String {
        get { sStyle ?? "" }
        set { sStyle = newValue }
    }
    
    public var lastUsed: Date {
        get { sLastUsed ?? Date.distantPast }
        set { sLastUsed = newValue }
    }
}
