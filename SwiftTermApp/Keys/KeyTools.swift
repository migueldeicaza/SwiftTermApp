//
//  KeyTools.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/13/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation

class KeyTools {
    static func generateKey (type: KeyType, secureEnclaveKeyTag: String, comment: String, passphrase: String)-> Key?

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
                        Key.getIdForKeychain(forId: keyUuid),
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
            let key = Key(id: keyUuid,
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
            
            return Key (id: keyUuid,
                        type: type,
                        name: comment,
                        privateKey: pemPrivate,
                        publicKey: publicKey,
                        passphrase: passphrase)
        }
    }
    
    
}

