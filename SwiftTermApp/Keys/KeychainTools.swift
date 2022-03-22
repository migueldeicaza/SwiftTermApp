//
//  KeychainTools.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/22/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

// Resources:
// - Unique key for the class "kSecClassGenericPassword"
//   https://stackoverflow.com/questions/11614047/what-makes-a-keychain-item-unique-in-ios

import Foundation

/// Returns a pair of dictionaries suitable for storing passphrases: attributes for the query, and attributes to modify
/// - Parameters:
///  - kind: the key that will be set on the keychain (like "SwiftTermAppKeyPassword")
///  - value: the id that this is linked to (usually the UUID that links to the original source)
///  - password: the password to store, if nil, then no attribute is added for it
///  - fetch: set attributes to retrieve a value
///  - split: if split, then the updating attribute for the password is returned on the second CFDictionary, otherwise on the first
func _getPassphraseQuery (kind: String, value: String, password: String?, fetch: Bool, split: Bool) -> (CFDictionary, CFDictionary) {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        
        kSecAttrService as String: kind,
        kSecAttrAccount as String: value,
        
    ]
    var attrs: [String: Any] = [:]
    
    if let password = password {
        let data = Data (password.utf8) as CFData
        if split {
            attrs [kSecValueData as String] = data
        } else {
            query [kSecValueData as String] = data
        }
    }
    if fetch {
        query [kSecMatchLimit as String] = kSecMatchLimitOne
        query [kSecReturnData as String] = kCFBooleanTrue
    } else {
        // Additional configuration
        //  - Key is backed up and moved to other devices
        query [kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        // - iCloud sync: TODO, need to sync the other data as well
        // query[kSecAttrSynchronizable as String] = kCFBooleanTrue
    }

    return (query as CFDictionary, attrs as CFDictionary)
}

// Would like to use this to produce a unique key in accordance to the
// resource above, but iOS does not support the kSecAttrKeyTypeECDSA,
// which is what we actually are using, so for now, we do not use this.
//
//    func getKeyTypeForKeyChain () -> CFString {
//        switch type {
//
//        case .ecdsa(_):
//            // return kSecAttrKeyTypeEC
//        case .rsa(_):
//            return kSecAttrKeyTypeRSA
//        }
//    }

/// Returns a pair of dictionaries suitable for storing a key: attributes for the query, and attributes to modify
/// - Parameters:
///  - kind: the key that will be set on the keychain (like "SwiftTermAppKeyPassword")
///  - value: the identifier for this passphrase
///  - key: the key to store, if nil, then no attribute is added for it
///  - fetch: set attributes to retrieve a value
///  - split: if split, then the updating attribute for the password is returned on the second CFDictionary, otherwise on the first
func _getPrivateKeyQuery (kind: String, value: String, key: String?, fetch: Bool, split: Bool) -> (CFDictionary, CFDictionary) {
    var query: [String: Any] = [
        kSecClass as String: kSecClassKey,

        // Unique key for the class "kSecClassKey"
        // https://stackoverflow.com/questions/11614047/what-makes-a-keychain-item-unique-in-ios

        kSecAttrApplicationLabel as String: kind,
        kSecAttrApplicationTag as String: value,
        //kSecAttrKeyType as String: getKeyTypeForKeyChain (),
    ]
    var attrs: [String: Any] = [:]
    if let key = key {
        let data = Data (key.utf8) as CFData
        if split {
            attrs [kSecValueData as String] = data
        } else {
            query [kSecValueData as String] = data
        }
    }
    if fetch {
        query [kSecMatchLimit as String] = kSecMatchLimitOne
        query [kSecReturnData as String] = kCFBooleanTrue
    } else {
        // Additional configuration
        //  - Key is backed up and moved to other devices
        query [kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        //TODO
        //query[kSecAttrSynchronizable as String] = kCFBooleanTrue
    }
    return (query as CFDictionary, attrs as CFDictionary)
}

/// Returns a pair of dictionaries suitable for storing a key: attributes for the query, and attributes to modify
/// - Parameters:
///  - id: the identifier for this passphrase
///  - key: the key to store, if nil, then no attribute is added for it
///  - fetch: set attributes to retrieve a value
///  - split: if split, then the updating attribute for the password is returned on the second CFDictionary, otherwise on the first

public func getPrivateKeyQuery (id: String, key: String?, fetch: Bool = false, split: Bool = false) -> (CFDictionary, CFDictionary) {
    return _getPrivateKeyQuery(kind: "SwiftTermAppPrivateKey", value: id, key: key, fetch: fetch, split: split)
}

/// Returns a pair of dictionaries suitable for storing passphrases: attributes for the query, and attributes to modify
/// - Parameters:
///  - id: the id that this is linked to (usually the UUID that links to the original source)
///  - password: the password to store, if nil, then no attribute is added for it
///  - fetch: set attributes to retrieve a value
///  - split: if split, then the updating attribute for the password is returned on the second CFDictionary, otherwise on the first

public func getPassphraseQuery (id: String, password: String?, fetch: Bool = false, split: Bool = false) -> (CFDictionary, CFDictionary) {
    return _getPassphraseQuery(kind: "SwiftTermAppKeyPassphrase", value: id, password: password, fetch: fetch, split: split)
}

/// Returns a pair of dictionaries suitable for storing host passwords: attributes for the query, and attributes to modify
/// - Parameters:
///  - id: the id that this is linked to (usually the UUID that links to the original source)
///  - password: the password to store, if nil, then no attribute is added for it
///  - fetch: set attributes to retrieve a value
///  - split: if split, then the updating attribute for the password is returned on the second CFDictionary, otherwise on the first

public func getHostPasswordQuery (id: String, password: String?, fetch: Bool = false, split: Bool = false) -> (CFDictionary, CFDictionary) {
    return _getPassphraseQuery(kind: "SwiftTermAppHostPassword", value: id, password: password, fetch: fetch, split: split)
}
