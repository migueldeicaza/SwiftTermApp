//
//  DataModelTypes.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/19/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

/// Represents a host we connect to, the data structure we save, and keep at runtime
/// Most properties are used at connection time, and a handful can be changed at runtime:
///
/// Properties that can be changed at runtime:
/// - style:
/// - background
/// - backspaceAsControlH
///
/// Possibly should add; Font and FontSize
protocol Host {
    /// Unique ID, used both inside Swift to differentiate structures and for tracking our records and keys
    var id: UUID { get set }

    /// Public name for this host
    var alias: String { get set }

    /// Address to connect to
    var hostname: String { get set }

    /// Setting for this host, should the backspace key send a control-h
    var backspaceAsControlH: Bool { get set }

    /// The port to which we will connect in the host
    var port: Int { get set }

    /// If true, this host uses a password, rather than a key
    var usePassword: Bool { get set }

    /// Username to login as
    var username: String { get set }

    /// If usePassword is set, this might contain the password to provide for authentication
    var password: String { get set }

    /// The guessed host type - this is used to pick the icon for the host, and it is sometimes automatically guessed and set
    var hostKind: String { get set }

    /// Environment variables to pass on the connection
    var environmentVariables: [String:String] { get set }

    /// Scripts to execute on startup
    var startupScripts: [String] { get set }

    /// This is the UUID of the key registered with the app
    var sshKey: UUID? { get set }

    /// The current color theme style name, if the style is "" it means "use the default"
    var style: String { get set }

    /// The values are `default` to pick the value from settings, "" to use a solid color, or the name of a live background
    var background: String { get set }

    /// Last time this host was used, to show the sorted list of hosts used
    var lastUsed: Date { get set }

    /// Reconnection type, one of "" or "tmux"
    var reconnectType: String { get set }
    
    /// Converts this host into a memory representation, not a database representation, so we can safely access CoreData structures from the background
    func asMemory () -> MemoryHost
}

extension Host {
    func summary() -> String {
        hostname + (style != "" ? ", \(style)" : "")
    }
}

protocol Key {
    /// Unique ID, used both inside Swift to differentiate structures and for tracking our records and keys
    var id: UUID { get set }
    
    /// The type of this key
    var type: KeyType { get set }
    
    /// The user visible name for the key
    var name: String { get set }
    
    /// This stores the private key as pasted by the user, or if it is a type = .ecdsa(inSecureEnclave:true) the tag for the key in the KeyChain
    var privateKey: String { get set }
    
    /// This stores the public key as pasted by the user
    var publicKey: String { get set }
    
    /// This stores a passphrase to decode the private key, if provided
    var passphrase: String { get set }
    
    func toMemoryKey () -> MemoryKey
}

extension Key {
    /// Turns the `publicKey` that contains base64 data into a `Data` object
    public func getPublicKeyAsData () -> Data {
        let values = publicKey.split (separator: " ")
        if values.count > 2 {
            if let decoded =  Data (base64Encoded: String (values [1])) {
                return decoded
            }
        }
        return Data()
    }
    
    /// If the key is stored in the KeyChain, returns the handle
    public func getKeyHandle () -> SecKey? {
        switch type  {
        case .ecdsa(inEnclave: true):
            let query = getKeyQuery(forId: id)
            var result: CFTypeRef!
            
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess && result != nil {
                return (result as! SecKey)
            }
            return nil
        default:
            return nil
        }
    }

}

protocol UserSnippet {
    var title: String { get set }
    var command: String { get set }
    var platforms: [String] { get set }
    var id: UUID { get set }

    func toMemoryUserSnippet () -> MemoryUserSnippet
}


