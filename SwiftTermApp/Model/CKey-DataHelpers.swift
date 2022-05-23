//
//  CKey-DataHelpers.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/20/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import CoreData

extension CKey: Key {
    convenience init (context: NSManagedObjectContext, blueprint: Key) {
        self.init (context: context)
        id = blueprint.id
        type = blueprint.type
        name = blueprint.name
        privateKey = blueprint.privateKey
        publicKey = blueprint.publicKey
        passphrase = blueprint.passphrase
    }
    
    public var id: UUID {
        get {
            if sId == nil {
                sId = UUID ()
            }
            return sId!
        }
        set { sId = newValue }
    }

    // TODO: this should be nullable
    var type: KeyType {
        get {
            guard let sKeyType = sKeyType else {
                // TODO
                return .rsa(1)
            }
            if sKeyType.starts(with: "rsa-") {
                if let n = Int (sKeyType.dropFirst(4)) {
                    return .rsa (n)
                }
                // TODO
                return .rsa(1)
            }
            if sKeyType == "ecdsa-secure-enclave" {
                return .ecdsa(inEnclave: true)
            }
            if sKeyType == "ecdsa" {
                return .ecdsa(inEnclave: false)
            }
            // TODO
            return .rsa(1)
        }
        set {
            switch newValue {
            case .ecdsa(inEnclave: true):
                sKeyType = "ecdsa-secure-enclave"
            case .ecdsa(inEnclave: false):
                sKeyType = "ecdsa"
            case .rsa(let bits):
                sKeyType = "rsa-\(bits)"
            }
        }
    }
    
    var name: String {
        get { sName ?? "" }
        set { sName = newValue }
    }
    
    var privateKey: String {
        get { loadKeyChainPrivateKey () }
        set { _ = saveKeyChainPrivateKey (newKey: newValue) }
    }
    
    var publicKey: String {
        get { sPublicKey ?? "" }
        set { sPublicKey = newValue }
    }
    
    var passphrase: String {
        get { loadKeyChainPassphrase () }
        set { _ = saveKeyChainPassphrase (newPassphrase: newValue) }
    }

    func loadKeyChainPrivateKey () -> String {
        let idKey = id.uuidString
        var itemCopy: AnyObject?

        let (queryKey, _) = getPrivateKeyQuery(id: idKey, key: nil, fetch: true)
        let status2 = SecItemCopyMatching(queryKey, &itemCopy)
        if status2 != errSecSuccess {
            print ("oops")
        }
        if let ic = itemCopy as? Data {
            return String (bytes: ic, encoding: .utf8) ?? ""
        }
        return ""
    }
    
    func saveKeyChainPrivateKey (newKey: String) -> OSStatus {
        let idKey = id.uuidString
        let (queryKey, _) = getPrivateKeyQuery(id: idKey, key: newKey)
        var status = SecItemAdd(queryKey, nil)
        if status == errSecDuplicateItem {
            let (queryKey, attrsToUpdateKey) = getPrivateKeyQuery(id: idKey, key: newKey, split: true)
            status = SecItemUpdate(queryKey, attrsToUpdateKey as CFDictionary)
        }
        return status
    }
    
    func loadKeyChainPassphrase () -> String {
        let idKey = id.uuidString
        let (query, _) = getPassphraseQuery(id: idKey, password: nil, fetch: true)
        
        var itemCopy: AnyObject?
        let status = SecItemCopyMatching(query, &itemCopy)
        if status != errSecSuccess {
            print ("oops")
        }
        if let d = itemCopy as? Data {
            return String (bytes: d, encoding: .utf8) ?? ""
        } else {
            return ""
        }
    }
    
    func saveKeyChainPassphrase (newPassphrase: String) -> OSStatus {
        let idKey = id.uuidString
        let (query, _) = getPassphraseQuery(id: idKey, password: newPassphrase)
        var status = SecItemAdd(query, nil)
        if status == errSecDuplicateItem {
            let (queryKey, attrsToUpdateKey) = getPrivateKeyQuery(id: idKey, key: newPassphrase, split: true)
            status = SecItemUpdate(queryKey, attrsToUpdateKey as CFDictionary)
        }
        return status
    }
    
    func keyChainDelete (_ query: CFDictionary, _ text: String) {
        let status = SecItemDelete(query)
        if status != errSecSuccess {
            let result = SecCopyErrorMessageString(status, nil).debugDescription
            print ("error: Deleting CKey's keychain payloads, \(text), \(result), query=\(query)")
        }
    }
    

    func deleteKeychainCompanionData () {
        KeyTools.dump ()
        
        let idKey = id.uuidString
        
        if privateKey == secureEnclaveKeyTag {
            // If there is an enclave component, deal with that
            let query = getKeyQuery(forId: id)
            // Ok this might fail because we are using the id and turning it into Data
            keyChainDelete (query, "Key's enclave component")
        }
        // TODO: check that this actually returns a value
        let (pass, _) = getPassphraseQuery(id: idKey, password: nil, fetch: true, forDelete: true)
        keyChainDelete(pass, "Key's passphrase component")
        
        let (queryKey, _) = getPrivateKeyQuery(id: idKey, key: nil, fetch: true, forDelete: true)
        keyChainDelete(queryKey, "Key's private key")
    }
    
    func toMemoryKey () -> MemoryKey {
        return MemoryKey (id: id, type: type, name: name, privateKey: privateKey, publicKey: publicKey, passphrase: passphrase)
    }
}
