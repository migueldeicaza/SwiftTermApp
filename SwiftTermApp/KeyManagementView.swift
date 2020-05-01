//
//  KeyManagementView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import CryptoKit

struct Key: Codable, Identifiable {
    let id = UUID()
    var type: String = ""
    var name: String = ""
    var privateKey: String = ""
    var publicKey: String = ""
    var passphrase: String = ""
}

enum KeyType {
    case ed25519
    case rsa(Int)
}

//
// This dialog can be used to create new SSH keys, and can either be
// for the secure enclave (so no passphrase is required), or regular
// ones with an optional passphrase
//
struct GenerateKeyView: View {
    @State var keyStyle:Int = 1
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
    var generateKey: (_ type: KeyType, _ comment: String, _ passphrase: String)->()
    
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
    
    func callGenerateKey ()
    {
        let v: KeyType = keyStyle == 0 ? .ed25519 : .rsa(keyBits == 0 ? 1024 : keyBits == 1 ? 2048 : 4096)
        generateKey(v, title, passphrase)
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
            }.listStyle(GroupedListStyle ())
                .environment(\.horizontalSizeClass, .regular)
                .navigationBarItems(
                    leading:  Button ("Cancel") {
                        self.showGenerator = false
                    },
                    trailing: Button("Save") {
                        if true || self.haveKey(self.keyName) {
                            self.showAlert = true
                        } else {
                            self.callGenerateKey()
                        }
                    }
            )
        }
        .alert(isPresented: self.$showAlert){
            Alert (title: Text ("Replace SSH Key"),
                   message: Text ("If you generate a new key, this will remove the previous key and any systems that had that key recorded will no longer accept connections from here.\nAre you sure you want to replace the existing SSH key?"),
                   primaryButton: Alert.Button.cancel({}),
                   
                   secondaryButton: .destructive(Text ("Replace"), action: self.callGenerateKey))
        }
    }
}

struct KeyButton: View {
    let highColor = Color(#colorLiteral(red: 0.007762347814, green: 0.4766914248, blue: 0.9985215068, alpha: 1))
    let backgroundColor = Color(#colorLiteral(red: 0.9307063222, green: 0.945577085, blue: 0.9838711619, alpha: 1))
    var text: String
    
    var body: some View {
        HStack {
            Spacer()
            Image (systemName: "plus.circle")
                .foregroundColor(highColor)
                .font(Font.title.weight(.semibold))
            Text (self.text)
                .foregroundColor(highColor)
                .fontWeight(.bold)
            Spacer()
        }
        .padding ()
        .background(backgroundColor)
        .cornerRadius(10)
        .foregroundColor(highColor)
        .padding()
    }
}

//
// This either uses the secure enclave to store the key (which is limited to the
// EC key, or an RSA key.
//
struct LocalKeyButton: View {
    @State var showGenerator = false
    let keyTag = "SE.ST.PK"
    
    func generateSecureEnclaveKey (_ type: KeyType, _ comment: String, _ passphrase: String)->()
    {
        switch type {
        case .ed25519:
            let access =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                            .privateKeyUsage,
                                            nil)!   // Ignore error
            
            let attributes: [String: Any] = [
                kSecAttrKeyType as String:            kSecAttrKeyTypeEC,
                kSecAttrKeySizeInBits as String:      256,
                kSecAttrTokenID as String:            kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String:     true,
                    kSecAttrApplicationTag as String:  keyTag,
                    kSecAttrAccessControl as String:   access
                ]
            ]
            
        case .rsa(let bits):
            if let (priv, pub) = try? CC.RSA.generateKeyPair(2048) {
                
            }
            break
        }
    }
    
    
    var body: some View {
        HStack {
            if false && SecureEnclave.isAvailable {
                KeyButton(text: "Create Local Key")
            }
        }.onTapGesture {
            self.showGenerator = true
        }.sheet(isPresented: self.$showGenerator) {
            // SecureEnclave SwiftTerm PrivateKey (SE.ST.PK)
            GenerateKeyView (showGenerator: self.$showGenerator, keyName: self.keyTag, generateKey: self.generateSecureEnclaveKey)
        }
    }
}

struct PasteKeyButton: View {
    @State var showGenerator = false
    
    var body: some View {
        KeyButton (text: "Import Key from Clipboard")
            .onTapGesture {
                self.showGenerator = true
            }
        .sheet (isPresented: self.$showGenerator) {
                AddKeyView (showGenerator: self.$showGenerator)
            }
    }
}

struct KeyManagementView: View {
    @State var newKeyShown = false
    @ObservedObject var store: DataStore = DataStore.shared
    
    var body: some View {
        List {
            // LocalKeyButton ()
            PasteKeyButton ()
            ForEach(store.keys){ key in
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "lock")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24)
                        .padding(8)
                    VStack (alignment: .leading) {
                        Text ("\(key.name)")
                            .font(.body)
                        Text ("Key Type: \(key.type)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }.cornerRadius(10)
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Keys")
        .navigationBarItems(trailing: HStack {
            Button (action: {
                self.newKeyShown = true
            }) {
                Image (systemName: "plus")
            }.sheet(isPresented: self.$newKeyShown) {
                GenerateKeyView(showGenerator: self.$newKeyShown, generateKey: { a, b, c in } )
            }
        })
    }
}

struct KeyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GenerateKeyView(showGenerator: .constant(true), generateKey: { a, b, c in })
            KeyManagementView()
        }
    }
}

