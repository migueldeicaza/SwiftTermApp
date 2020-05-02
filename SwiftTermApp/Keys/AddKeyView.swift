//
//  AddKeyView.swift
//
//  Used to paste an SSH public/private key and store it
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI


struct AddKeyView: View {
    @Binding var showGenerator: Bool
    @State var key: Key = Key()
    @State var showingPassword = false
    var disableSave: Bool {
        key.name == "" || key.privateKey == ""
    }
    
    var body: some View {
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
                }
                VStack {
                    HStack {
                        Text ("Public Key")
                        Spacer ()
                    }
                    TextField ("Optional", text: self.$key.publicKey)
                }
                HStack {
                    Text ("Passphrase")
                    if showingPassword {
                        TextField ("•••••••", text: self.$key.passphrase)
                            .multilineTextAlignment(.trailing)
                    
                    } else {
                        SecureField ("•••••••", text: self.$key.passphrase)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Button (action: { self.showingPassword.toggle () }, label: {
                        Text (self.showingPassword ? "HIDE" : "SHOW").foregroundColor(Color (UIColor.link))
                    })
                }
            }
        }.navigationBarItems(
            leading:  Button ("Cancel") {},
            trailing: Button("Save") {
        
        }.disabled (disableSave))
    }
}
struct PasteKey_Previews: PreviewProvider {
    
    static var previews: some View {
        Text ("").sheet(isPresented: .constant (true)) {
            AddKeyView(showGenerator: .constant(true))
        }
    }
}
