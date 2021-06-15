//
// PEMtoSSH.swift - from https://github.com/App-Maker-Software/GitProviders/blob/main/Sources/GitProviders/Work/Crypto/PEMToSSHPublicKeyFormat.swift
// Which is licensed under the MIT license
//
//

import Foundation

/// Takes a public RSA key produced by CC.RSA.generateKeyPair and returns it in an ssh public key compaible form
func publicPEMKeyToSSHFormat(data: Data) throws -> String {
    let node = try! Asn1Parser.parse(data: data)
    
    // Ensure the raw data is an ASN1 sequence
    guard case .sequence(let nodes) = node else {
        throw NSError()
    }
    
    let RSA_HEADER = "ssh-rsa"
    
    var ssh:String = RSA_HEADER + " "
    var rsaBytes:Data = Data()
    
    // Get size of the header
    var byteCount: UInt32 = UInt32(RSA_HEADER.count).bigEndian
    var sizeData = Data(bytes: &byteCount, count: MemoryLayout.size(ofValue: byteCount))
    
    // Append size of header and content of header
    rsaBytes.append(sizeData)
    rsaBytes += RSA_HEADER.data(using: .utf8)!
    
    // Get the exponent
    if let exp = nodes.last, case .integer(let exponent) = exp {
        // Get size of exponent
        byteCount = UInt32(exponent.count).bigEndian
        sizeData = Data(bytes: &byteCount, count: MemoryLayout.size(ofValue: byteCount))
        
        // Append size of exponent and content of exponent
        rsaBytes.append(sizeData)
        rsaBytes += exponent
    }
    else{
        throw NSError()
    }
    
    // Get the modulus
    if let mod = nodes.first, case .integer(let modulus) = mod {
        // Get size of modulus
        byteCount = UInt32(modulus.count).bigEndian
        sizeData = Data(bytes: &byteCount, count: MemoryLayout.size(ofValue: byteCount))
        
        // Append size of modulus and content of modulus
        rsaBytes.append(sizeData)
        rsaBytes += modulus
    }
    else{
        throw NSError()
    }
    
    ssh += rsaBytes.base64EncodedString() + "\n"
    return ssh
}
