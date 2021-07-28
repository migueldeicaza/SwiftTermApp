//
//  SshUtil.swift - Utility functions to interoperate with SSH
//
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/29/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//
import Foundation

class SshUtil {
    public static func encode (str: String) -> Data {
        guard let utf8 = str.data(using: .utf8) else {
            return Data()
        }
        return encode (utf8.count) + utf8
    }

    public static func encode (data: Data) -> Data {
        //let sum = data.reduce ("") { res, n in "\(res), \(String(format:"%02X", n))"}
        return encode (data.count) + data
    }

    public static func encode (_ int: Int) -> Data {
        var bigEndianInt = Int32 (int).bigEndian
        return Data (bytes: &bigEndianInt, count: 4)
    }
    
    ///
    /// Given a SecKey that represents a public key created with kSecAttrKeyTypeECSECPrimeRandom 256 bits
    /// returns the packaged binary.   This binary should be both base64-encoded, and then additional data should
    /// be added to make it suitable to be given to SSH.
    ///
    static func generateSshPublicKeyData (k: SecKey) -> Data? {
        var error: Unmanaged<CFError>? = nil

        guard let data = SecKeyCopyExternalRepresentation (k, &error) as Data? else {
            print ("Got \(String(describing: error)) while extracting the key representation")
            return nil
        }
        return encode (str: "ecdsa-sha2-nistp256") + encode (str: "nistp256") + encode (data: data)
    }
    
    ///
    /// Given a SecKey that represents a public key created with kSecAttrKeyTypeECSECPrimeRandom 256 bits
    /// returns a public key suitable to be added to ssh `authorized_keys`.   The comment is added as part
    /// of the returned public key.
    ///
    public static func generateSshPublicKey (k: SecKey, comment: String) -> String? {
        guard let inner = generateSshPublicKeyData (k: k) else {
            return nil
        }
        return "ecdsa-sha2-nistp256 \(inner.base64EncodedString()) \(comment)"
    }
    
    /// The generated private key, sometimes contains a value that is treated by ssh as negative (the
    /// top bit is 1), this little bit of code inserts a 0 to the signature, to ensure that the value is not
    /// treated as a negative.
    ///
    /// Background: the `sshbuf_get_bignum2_bytes_direct` in sshbuf-getput-basic.c
    /// refuses negative bignums:
    /// ```    /* Refuse negative (MSB set) bignums */
    ///        if ((len != 0 && (*d & 0x80) != 0))
    ///                return SSH_ERR_BIGNUM_IS_NEGATIVE;
    /// ```
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

    static let headerOpenSshPrivateKey = "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    static let footerOpenSshPrivateKey = "\n-----END OPENSSH PRIVATE KEY-----\n"

    ///
    /// WARNING: this does not use passphrases, nor does it attempt to encrypt the content with the passphrase.
    ///
    /// Given a pair of SecKey that represent the public and private keys created with kSecAttrKeyTypeECSECPrimeRandom 256 bits
    /// this returns a private key without a passphrase set that can be as an identity that will work against the public key here.
    ///
    /// The purpose of this routine is purely to assist in the debugging of the kind of keys that can be created on the secure
    /// enclave, and can be used to debug the SSH authentication workflow, and nothing more.
    ///
    public static func generateSshPrivateKey (pub: SecKey, priv: SecKey, comment: String) -> String? {
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
        return headerOpenSshPrivateKey + content.base64EncodedString(options: .lineLength76Characters) + footerOpenSshPrivateKey
    }

    /// Given a host key as returned by session.hostKey, returns the type of the key
    public static func extractKeyType (_ bytes: [Int8]) -> String? {
        let data = Data (bytes.map { UInt8 (bitPattern: $0)})

        if data.count < 4 {
            return nil
        }

        let count = (data [0] << 24 | data [1] << 16 | data [2] << 8 | data [3])
        let last = 4 + count
        if data.count < last {
            return nil
        }
        return String (data: data [4..<last], encoding: .utf8)
    }

    public static func openSSHKeyRequiresPassword (key: String) -> Bool {
        guard key.contains(headerOpenSshPrivateKey) && key.contains (footerOpenSshPrivateKey) else {
            return false
        }
        let sub = key.replacingOccurrences(of: headerOpenSshPrivateKey, with: "").replacingOccurrences(of: footerOpenSshPrivateKey, with: "")
        guard let key = Data (base64Encoded: sub, options: .ignoreUnknownCharacters) else {
            return false
        }
        guard key.count > 64 else {
            return false
        }
        guard String (bytes: key [0...14], encoding: .utf8) == "openssh-key-v1\u{0}" else {
            return false
        }
        let n = key [15] << 24 | key [16] << 16 | key [17] << 8 | key [18]
        if n == 4 && String (bytes: key [19..<23], encoding: .utf8) == "none" {
            return false
        }
        return true
    }
}
