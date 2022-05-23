//
//  KeyTools.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/13/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation

class KeyTools {
    static func generateKey (type: KeyType, secureEnclaveKeyTag: String, comment: String, passphrase: String)-> MemoryKey?

    {
        let keyUuid = UUID()
        
        switch type {
        case .ecdsa (let inSecureEnclave):
            let access =
            SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .privateKeyUsage,
                nil)!   // Ignore error

            let attributes: [String: Any]
                        
            if inSecureEnclave {
                attributes = [
                kSecAttrKeyType as String:            kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String:      256,
                kSecAttrTokenID as String:            kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String:     true,
                    kSecAttrApplicationTag as String:
                        getIdForKeychain(forId: keyUuid),
                    kSecAttrAccessControl as String:   access
                ]
                ]
            } else {
                attributes = [
                kSecAttrKeyType as String:            kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String:      256,
                ]
            }
            
            var error: Unmanaged<CFError>? = nil
            guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                print ("Oops: \(error.debugDescription)")
                return nil
            }
            let publicKey = SecKeyCopyPublicKey  (privateKey)
            
            guard let publicText = SshUtil.generateSshPublicKey(k: publicKey!, comment: comment) else {
                print ("Could not produce the public key")
                return nil
            }
            
            let privateText: String
            if inSecureEnclave {
                privateText = secureEnclaveKeyTag
            } else {
                guard let p = SshUtil.generateSshPrivateKey(pub: publicKey!, priv: privateKey, comment: comment) else {
                    print ("Could not produce the private key")
                    return nil
                }
                privateText = p
            }
            let key = MemoryKey(
                id: keyUuid,
                type: type,
                name: comment,
                privateKey: privateText,
                publicKey: publicText,
                passphrase: "")
            return key
            
        case .rsa(let bits):
            guard let (priv, pub) = try? CC.RSA.generateKeyPair(bits) else {
                return nil
            }

            guard let pemPublic = try? publicPEMKeyToSSHFormat(data: pub) else {
                return nil
            }
            let publicKey = pemPublic.replacingOccurrences(of: "\n", with: " \(comment)\n")
            
            let pemPrivate = passphrase == ""
                ? PEM.PrivateKey.toPEM(priv)
                : PEM.EncryptedPrivateKey.toPEM(priv, passphrase: passphrase, mode: .aes256CBC)
            
            return MemoryKey (id: keyUuid,
                        type: type,
                        name: comment,
                        privateKey: pemPrivate,
                        publicKey: publicKey,
                        passphrase: passphrase)
        }
    }

    static let secItemClasses =  [
        kSecClassGenericPassword,
        kSecClassInternetPassword,
        kSecClassCertificate,
        kSecClassKey,
        kSecClassIdentity,
    ]

    // This resets the keychain for the app
    static func reset () {
        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            var status = SecItemDelete(spec)
            if status != errSecSuccess && status != errSecItemNotFound {
                let result = SecCopyErrorMessageString(status, nil).debugDescription
                print ("Error calling SecItemDelete: \(result)")
            }
            let specSync: NSDictionary = [kSecClass: itemClass, kSecAttrSynchronizable as String: kSecAttrSynchronizableAny]
            status = SecItemDelete(specSync)
            if status != errSecSuccess && status != errSecItemNotFound {
                let result = SecCopyErrorMessageString(status, nil).debugDescription
                print ("Error calling SecItemDelete on the sync case: \(result)")
            }
        }
    }
    
    // This dumps the state of the keychain
    static func dump () {
        for itemClass in secItemClasses {
            for sync in [true, false] {
                var query: [String: Any] = [
                    kSecClass as String: itemClass,
                    kSecMatchLimit as String: kSecMatchLimitAll,
                    kSecReturnRef as String: true,
                    kSecReturnAttributes as String: true,
                ]
                    if sync {
                        query [kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
                    }
                var itemCopy: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &itemCopy)
                if status != 0 {
                    //print ("No entries for \(itemClass)[sync=\(sync)]")
                    continue
                }
                if let array = itemCopy as? NSArray {
                    print ("Found \(array.count) elements for \(itemClass)[sync=\(sync)]")
                    for element in array {
                        if let dict = element as? NSDictionary {
                            print ("    " + dict.debugDescription.replacingOccurrences(of: "\n", with: "\n    "))
                            //let ref = dict.object(forKey: kSecValueRef)
                            if let desc = dict.object(forKey: kSecAttrDescription) {
                                print ("   description = \(desc)")
                            }
                            if let comment = dict.object(forKey: kSecAttrComment) {
                                print ("   comment = \(comment)")
                            }
                            if let label = dict.object(forKey: kSecAttrLabel) {
                                print ("   label = \(label)")
                            }
                            if let account = dict.object(forKey: kSecAttrAccount) {
                                print ("   account = \(account)")
                            }
                            
                        } else {
                            print ("Unknown type")
                        }
                    }
                } else {
                    if itemCopy != nil {
                        print ("Dump: was expecting an array, did not get it")
                    }
                }
            }
        }
    }
    
}

