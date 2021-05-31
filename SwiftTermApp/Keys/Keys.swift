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
        return encode (str: "ecdsa-sha2-nistp256") + encode (str: "nistp256") + encode (data.count) + data
    }
    
    public static func generateSshPublicKey (k: SecKey, msg: String) -> String? {
        guard let inner = generateSshPublicKeyData (k: k) else {
            return nil
        }
        return "ecdsa-sha2-nistp256 \(inner.base64EncodedString()) \(msg)"
    }
    
    public static func generateSshPrivateKey (pub: SecKey, priv: SecKey) -> String? {
        let header = "-----: PRIVATE KEY-----\n"
        let footer = "\n-----END OPENSSH PRIVATE KEY-----\n"
        var content: Data
        guard let pubEncoded = generateSshPublicKeyData(k: pub) else {
            return nil
        }
        var error: Unmanaged<CFError>? = nil

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
        content.append (encode(str: ciphername))
        content.append (encode (str: kdfname))
        content.append (encode (kdf))
        content.append (encode (keycount))
        content.append (encode (data: pubEncoded))
            // missing: wrapper for the following:
        // RND (2 32-bit values repeated)
        // LENOF(X) + X="keytype" -> ecdsa-sha2-nistp256
        // LENFOX(X) + X="nistp256"
        // privData
        // MISSING: LEN of a 32-bit blob, plus the blob
        // 32-bit len + comment
        // pad to blocksize 1, 2, 3, 4 bytes j
        content.append (encode (data: privData))
        
        return header + content.base64EncodedString(options: .lineLength76Characters) + footer
    }
}
struct Keys_Previews: PreviewProvider {
    static var previews: some View {
        Keys()
    }
}
