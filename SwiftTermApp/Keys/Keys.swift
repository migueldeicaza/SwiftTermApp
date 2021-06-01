//
//  Keys.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/29/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

enum KeyType {
    case ed25519
    case rsa(Int)
}

struct Keys: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

class SshUtil {
    public static func encode (str: String) -> Data {
        guard let utf8 = str.data(using: .utf8) else {
            return Data()
        }
        return encode (utf8.count) + utf8
    }

    public static func encode (data: Data) -> Data {
        let sum = data.reduce ("") { res, n in "\(res), \(String(format:"%02X", n))"}
        print ("Encoding data \(data.count) -> \(sum)")
        return encode (data.count) + data
    }

    public static func encode (_ int: Int) -> Data {
        var bigEndianInt = Int32 (int).bigEndian
        return Data (bytes: &bigEndianInt, count: 4)
    }
    
    public static func generateSshPublicKeyData (k: SecKey) -> Data? {
        var error: Unmanaged<CFError>? = nil

        guard let data = SecKeyCopyExternalRepresentation (k, &error) as Data? else {
            print ("Got \(String(describing: error)) while extracting the key representation")
            return nil
        }
        return encode (str: "ecdsa-sha2-nistp256") + encode (str: "nistp256") + encode (data: data)
    }
    
    public static func generateSshPublicKey (k: SecKey, comment: String) -> String? {
        guard let inner = generateSshPublicKeyData (k: k) else {
            return nil
        }
        return "ecdsa-sha2-nistp256 \(inner.base64EncodedString()) \(comment)"
    }
    
    static func prepareSignature (_ data: Data) -> Data {
        var copy = Data (data)
        // Check if we need to pad with 0x00 to prevent certain
        // ssh servers from thinking r or s is negative
        let paddingRange: ClosedRange<UInt8> = 0x80...0xFF
        if paddingRange ~= copy.first! {
            copy.insert(0x00, at: 0)
        }
        return copy
    }
    
    public static func generateSshPrivateKey (pub: SecKey, priv: SecKey, comment: String) -> String? {
        let header = "-----BEGIN OPENSSH PRIVATE KEY-----\n"
        let footer = "\n-----END OPENSSH PRIVATE KEY-----\n"
        var content: Data
        guard let pubEncoded = generateSshPublicKeyData(k: pub) else {
            return nil
        }
        var error: Unmanaged<CFError>? = nil

        guard let pubData = SecKeyCopyExternalRepresentation (pub, &error) as Data? else {
            print ("Got \(String(describing: error)) while extracting the public key representation")
            return nil
        }
        
        guard let privData = SecKeyCopyExternalRepresentation (priv, &error) as Data? else {
            print ("Got \(String(describing: error)) while extracting the private key representation")
            return nil
        }

        let ciphername = "none"
        let kdfname = "none"
        let kdf = 0
        let keycount = 1
        
        content = "openssh-key-v1".data(using: .utf8)!
        content.append(0)
        content.append (encode (str: ciphername))
        content.append (encode (str: kdfname))
        content.append (encode (kdf))
        content.append (encode (keycount))
        content.append (encode (data: pubEncoded))
            // missing: wrapper for the following:
        
        var rnd = UInt32.random(in: 0..<UInt32.max)
        var subBlock = Data ()
        // dummy checksum
        subBlock.append (Data (bytes: &rnd, count: 4))
        subBlock.append (Data (bytes: &rnd, count: 4))
        subBlock.append (encode (str: "ecdsa-sha2-nistp256"))
        subBlock.append (encode (str: "nistp256"))
        subBlock.append (encode (data: pubData))
        
        let d = prepareSignature (privData [pubData.count...])
        subBlock.append (encode (data: d))
        subBlock.append (encode (str: comment))
        var padding: UInt8 = 1
        while (subBlock.count % 8) != 0 {
            subBlock.append(padding)
            padding += 1
        }
        content.append(encode (data: subBlock))
        return header + content.base64EncodedString(options: .lineLength76Characters) + footer
    }
}
struct Keys_Previews: PreviewProvider {
    static var previews: some View {
        Keys()
    }
}
