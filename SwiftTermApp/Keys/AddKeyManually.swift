//
//  AddKeyView.swift
//
//  Used to paste an SSH public/private key and store it
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

//
// Implements adding a new Key from pasted data
struct AddKeyManually: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @Binding var addKeyManuallyShown: Bool
    @State var key: Key = Key()
    @State var showingPassword = false
    
    var disableSave: Bool {
        key.name == "" || key.privateKey == ""
    }
    
    func saveAndLeave ()
    {
        store.save (key: self.key)
        addKeyManuallyShown = false
    }
    
    // Tries to do something smart for adding the key by default
    func setupKey ()
    {
        // Maybe the clipboard has a key
        let clip = UIPasteboard.general
        if clip.hasStrings {
            if let value = clip.string {
                if value.contains("BEGIN OPENSSH PRIVATE KEY") {
                    key.privateKey = value
                } else if value.starts(with: "ssh-rsa") || value.starts(with: "ssh-dss") || value.starts(with: "ecdsa-sha2-nistp256") || value.starts(with: "ssh-ed25519") {
                    key.publicKey = value
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            
            Form {
                Section {
                    VStack {
                        HStack {
                            Text ("Name")
                            Spacer ()
                        }
                        TextField ("Required", text: self.$key.name)
                    }
                    VStack {
                        HStack {
                            Text ("Private Key")
                            Spacer ()
                        }
                        TextField ("Required", text: self.$key.privateKey)
                            .autocapitalization(.none)
                    }
                    VStack {
                        HStack {
                            Text ("Public Key")
                            Spacer ()
                        }
                        TextField ("Optional", text: self.$key.publicKey)
                            .autocapitalization(.none)
                    }
                    HStack {
                        Text ("Passphrase")
                        if showingPassword {
                            TextField ("•••••••", text: self.$key.passphrase)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                        } else {
                            SecureField ("•••••••", text: self.$key.passphrase)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                        }
                        
                        Button (action: { self.showingPassword.toggle () }, label: {
                            Text (self.showingPassword ? "HIDE" : "SHOW").foregroundColor(Color (UIColor.link))
                        })
                    }
                }
            }
            .navigationBarItems(
                leading:  Button ("Cancel") { self.addKeyManuallyShown = false },
                trailing: Button("Save") { self.saveAndLeave() }
                    .disabled (disableSave))
        }.onAppear {
            self.setupKey ()
        }
    }
}
struct PasteKey_Previews: PreviewProvider {
    
    static var previews: some View {
        Text ("").sheet(isPresented: .constant (true)) {
            AddKeyManually(addKeyManuallyShown: .constant(true))
        }
    }
}
