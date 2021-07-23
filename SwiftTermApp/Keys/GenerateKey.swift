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

enum KeyType: Codable, CustomStringConvertible {
    var description: String {
        get {
            switch self {
            case .ecdsa(let inEnclave):
                return inEnclave ? "ECDSA/Secure Enclave" : "ECDSA"
            case .rsa(let bits):
                return "RSA \(bits)"
            }
        }
    }
    
    case ecdsa(inEnclave: Bool)
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
    @State var showKeyError: Bool = false
    
    // Externally settable
    
    @State var passphrase: String = ""
    var keyName: String = ""
    
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
        let v: KeyType = keyStyle == 0 ? .ecdsa(inEnclave: false) : .rsa(keyBits == 0 ? 1024 : keyBits == 1 ? 2048 : 4096)
        if let generated = KeyTools.generateKey (type: v, secureEnclaveKeyTag: "", comment: title, passphrase: passphrase) {
            DataStore.shared.save(key: generated)
        } else {
            // TODO
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
                Section {
                    // Currently, I only support passphrases for generated RSA keys
                    if self.keyStyle == 1 {
                        Passphrase(passphrase: $passphrase)
                    }
                    HStack {
                        Text ("Comment")
                        TextField ("", text: self.$title)
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
                            self.showGenerator = false
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
        .alert("Unable to generate key", isPresented: $showKeyError) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct GenerateKey_Previews: PreviewProvider {
    static var previews: some View {
        GenerateKey(keyStyle: 1, showGenerator: .constant(true))
    }
}
