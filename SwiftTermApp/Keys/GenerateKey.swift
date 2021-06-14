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

struct GenerateKey_Previews: PreviewProvider {
    static var previews: some View {
        GenerateKey(showGenerator: .constant(true), generateKey: { x, a, b in nil })
    }
}
