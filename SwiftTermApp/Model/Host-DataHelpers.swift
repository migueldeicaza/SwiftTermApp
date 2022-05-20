//
//  DataModel.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/16/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

extension CHost: Host {
    public var id: UUID {
        get {
            if sId == nil {
                sId = UUID ()
            }
            return sId!
        }
        set { sId = newValue }
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
    

    /// Saves the private components into the keychain
    public func savePasswordOnKeychain (password: String) -> OSStatus {
        let (query, _) = getHostPasswordQuery(id: id.uuidString, password: password)
        
        let status = SecItemAdd(query, nil)
        if status == errSecDuplicateItem {
            let (query2, update) = getHostPasswordQuery(id: id.uuidString, password: password, split: true)
            let status2 = SecItemUpdate(query2, update)
            
            return status2
        }
        return status
    }
    
    func loadKeychainPassword () -> String {
        let (query, _) = getHostPasswordQuery(id: id.uuidString, password: nil, fetch: true)

        var itemCopy: AnyObject?
        let status = SecItemCopyMatching(query, &itemCopy)
        if status != 0 {
            return ""
        }
        if let d = itemCopy as? Data {
            return String (bytes: d, encoding: .utf8) ?? ""
        } else {
            return ""
        }
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
        get { loadKeychainPassword() }
        set { _ = savePasswordOnKeychain(password: newValue) }
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
            guard let moc = self.managedObjectContext else {
                return
            }
            for x in (sEnvironmentVariables?.allObjects as? [CEnvironmentVariable] ?? []) {
                moc.delete(x)
            }
            var newSet = Set<CEnvironmentVariable>()
            for kp in newValue {
                let nested = CEnvironmentVariable (context: moc)
                nested.key = kp.key
                nested.value = kp.value
                newSet.update(with: nested)
            }
            sEnvironmentVariables = NSSet (set: newSet)
        }
    }
    
    public var startupScripts: [String] {
        get {
            let scripts = sStartupScripts?.allObjects as? [CScripts] ?? []
            return scripts.compactMap { $0.script ?? nil }
        }
        set {
            guard let moc = self.managedObjectContext else {
                return
            }
            for x in (sStartupScripts?.allObjects as? [CScripts] ?? []) {
                moc.delete(x)
            }
            var newSet = Set<CScripts>()
            for script in newValue {
                let nested = CScripts (context: moc)
                nested.script = script
                newSet.update(with: nested)
            }
            sStartupScripts = NSSet (set: newSet)
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
