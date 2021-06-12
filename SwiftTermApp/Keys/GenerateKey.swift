//
//  GenerateKey.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/6/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import CryptoKit
import Security

enum KeyType {
    case ecdsa
    case rsa(Int)
}

//
// This dialog can be used to create new SSH keys, and can either be
// for the secure enclave (so no passphrase is required), or regular
// ones with an optional passphrase
//
struct GenerateKey: View {
    @State var keyStyle:Int = 0
    @State var keyBits:Int = 1
    @State var title = "SwiftTerm key on \(UIDevice.current.name)"
    @Binding var showGenerator: Bool
    @State var showAlert: Bool = false
    
    // Externally settable
    
    // If not-nil, this should be a password to give to the key
    var usePassphrase: Bool = false
    @State var passphrase: String = ""
    var keyName: String = ""
    
    // Callback invoked with the desired key, it should generate the key
    // and add it to the keychain - this might be the secure enclave, or
    // a regular location for devices that do not have it.
    var generateKey: (_ type: KeyType, _ comment: String, _ passphrase: String)->Key?
    
    func haveKey (_ keyName: String) -> Bool
    {
        do {
            if try SwKeyStore.getKey(keyName) != "" {
                return true
            }
        } catch {
        }
        return false
    }
    
    @State var generated = ""
    func callGenerateKey ()
    {
        let v: KeyType = keyStyle == 0 ? .ecdsa : .rsa(keyBits == 0 ? 1024 : keyBits == 1 ? 2048 : 4096)
        if let generated = generateKey(v, title, passphrase) {
            DataStore.shared.save(key: generated)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section (header: Text ("KEY TYPE")) {
                    HStack {
                        Spacer ()
                        Picker("", selection: self.$keyStyle) {
                            Text ("ed25519")
                                .tag (0)
                            Text ("RSA")
                                .tag (1)
                        }.pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        Spacer ()
                    }
                }
                if self.keyStyle == 1 {
                    Section (header: Text ("NUMBER OF BITS")){
                        Picker("", selection: self.$keyBits) {
                            Text ("1024")
                                .tag (0)
                            Text ("2048")
                                .tag (1)
                            Text ("4096")
                                .tag (2)
                        }.pickerStyle(SegmentedPickerStyle())
                    }
                }
                if self.usePassphrase {
                    Section {
                        Text ("Passphrase")
                        TextField("Title", text: self.$passphrase)
                    }
                }
                Section {
                    HStack {
                        Text ("Comment")
                        TextField ("", text: self.$title)
                            .font(.subheadline)
                    }
                }
                Section {
                    HStack {
                        Text ("Generated Key")
                        TextField ("", text: self.$generated)
                            .font(.subheadline)
                    }
                }
            }
            .listStyle(GroupedListStyle ())
            .environment(\.horizontalSizeClass, .regular)
            .toolbar {
                ToolbarItem (placement: .navigationBarLeading) {
                    Button ("Cancel") {
                        self.showGenerator = false
                    }
                }
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button("Save") {
                        if false || self.haveKey(self.keyName) {
                            self.showAlert = true
                        } else {
                            self.callGenerateKey()
                        }
                    }
                }
            }
        }
        .alert(isPresented: self.$showAlert){
            Alert (title: Text ("Replace SSH Key"),
                   message: Text ("If you generate a new key, this will remove the previous key and any systems that had that key recorded will no longer accept connections from here.\nAre you sure you want to replace the existing SSH key?"),
                   primaryButton: Alert.Button.cancel({}),
                   
                   secondaryButton: .destructive(Text ("Replace"), action: self.callGenerateKey))
        }
    }
}



//
// This either uses the secure enclave to store the key (which is limited to the
// EC key, or an RSA key.
//
struct LocalKeyButton: View {
    @State var showGenerator = false
    @State var showLocalGenerator = false
    let keyTag = "SwiftTermSecureEnclave"
    
    func generateSecureEnclaveKey (_ type: KeyType, _ comment: String, _ passphrase: String)-> Key?
    {
        return generateKey (type, comment, passphrase, inSecureEnclave: true)
    }

    func generateLocalKey (_ type: KeyType, _ comment: String, _ passphrase: String)-> Key?
    {
        return generateKey (type, comment, passphrase, inSecureEnclave: false)
    }

    func generateKey (_ type: KeyType, _ comment: String, _ passphrase: String, inSecureEnclave: Bool)-> Key?

    {
        switch type {
        case .ecdsa:
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
                        keyTag.data(using: .utf8)! as CFData,
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
                privateText = keyTag
            } else {
                guard let p = SshUtil.generateSshPrivateKey(pub: publicKey!, priv: privateKey, comment: comment) else {
                    print ("Could not produce the private key")
                    return nil
                }
                privateText = p
            }
            return Key(id: UUID(),
                       type: inSecureEnclave ? "se-ecdsa" : "ecdsa",
                       name: comment,
                       privateKey: privateText,
                       publicKey: publicText,
                       passphrase: "")
            
            // TODO: not yet implemented
        case .rsa(let bits):
            if let (priv, pub) = try? CC.RSA.generateKeyPair(2048) {
                print ("\(priv) \(pub) \(bits)")
            }
            break
        }
        return nil
    }
    
    func haveSecureEnclaveKey () -> Bool {
        let lookupKey: [String:Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnRef as String: true]
        
        var item: CFTypeRef?
        return SecItemCopyMatching (lookupKey as CFDictionary, &item) == errSecSuccess && item != nil
    }
    
    var body: some View {
        VStack {
            if SecureEnclave.isAvailable {
                if haveSecureEnclaveKey() {
                    HStack {
                        Text ("Secure Enclave Key")
                        Image (systemName: "trash")
                        Image (systemName: "square.and.arrow.up")
                    }
                } else {
                    STButton(text: "Create Enclave Key", icon: "plus.circle")
                        .onTapGesture {
                            self.showGenerator = true
                        }
                }
            }

            STButton (text: "Create Key", icon: "plus.circle")
                .onTapGesture {
                    self.showLocalGenerator = true
                }
        }.sheet(isPresented: self.$showGenerator) {
            // SecureEnclave SwiftTerm PrivateKey (SE.ST.PK)
            GenerateKey (showGenerator: self.$showGenerator, keyName: self.keyTag, generateKey: self.generateSecureEnclaveKey)
        }.sheet(isPresented: self.$showLocalGenerator) {
            GenerateKey (showGenerator: self.$showGenerator, keyName: self.keyTag, generateKey: self.generateLocalKey)
        }
    }
}

struct GenerateKey_Previews: PreviewProvider {
    static var previews: some View {
        GenerateKey(showGenerator: .constant(true), generateKey: { x, a, b in nil })
    }
}
