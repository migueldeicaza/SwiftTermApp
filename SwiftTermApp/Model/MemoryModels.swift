//
//  MemoryModels.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/20/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

/// An pure in-memory implementation of the Host protocol
public class MemoryHost: Host {
    internal init(id: UUID = UUID(), alias: String = "", hostname: String = "", backspaceAsControlH: Bool = false, port: Int = 22, usePassword: Bool = true, username: String = "", password: String = "", hostKind: String = "", environmentVariables: [String:String] = [:], startupScripts: [String] = [], sshKey: UUID? = nil, style: String = "", background: String = "", lastUsed: Date = Date.distantPast) {
        self.id = id
        self.alias = alias
        self.hostname = hostname
        self.backspaceAsControlH = backspaceAsControlH
        self.port = port
        self.usePassword = usePassword
        self.username = username
        self.password = password
        self.hostKind = hostKind
        self.environmentVariables = environmentVariables
        self.startupScripts = startupScripts
        self.sshKey = sshKey
        self.style = style
        self.background = background
        self.lastUsed = lastUsed
    }
    
    var id = UUID()
    var alias: String = ""
    var hostname: String = ""
    var backspaceAsControlH: Bool = false
    var port: Int = 22
    var usePassword: Bool = true
    var username: String = ""
    var password: String = ""
    var hostKind: String = ""
    var environmentVariables: [String:String] = [:]
    var startupScripts: [String] = []
    var sshKey: UUID?
    var style: String = ""
    var background: String = ""
    var lastUsed: Date = Date.distantPast
    var reconnectType: String = ""
    
    func asMemory() -> MemoryHost {
        return self
    }
}

class MemoryKey: Key, Codable, Identifiable {
    var id: UUID
    var type: KeyType = .rsa(4096)
    var name: String = ""
    
    // This stores the private key as pasted by the user, or if it is a type = .ecdsa(inSecureEnclave:true) the tag for the key in the KeyChain
    var privateKey: String = ""
    // This stores the public key as pasted by the user
    var publicKey: String = ""
    var passphrase: String = ""
    
    // The list of keys that are serialized to Json, this is used to prevent both
    // passphrase and privateKey from being stored in plaintext.
    enum CodingKeys: CodingKey {
        case id
        case type
        case name
        case publicKey
#if DEBUG
        case passphrase
        case privateKey
#endif
    }
    
    public init (id: UUID = UUID(), type: KeyType = .rsa(4096), name: String = "", privateKey: String = "", publicKey: String = "", passphrase: String = "")
    {
        self.id = id
        self.type = type
        self.name = name
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.passphrase = passphrase
    }
    
    func toMemoryKey() -> MemoryKey {
        return self
    }
}
