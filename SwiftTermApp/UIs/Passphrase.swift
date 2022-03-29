//
//  Passphrase.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/14/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct Passphrase: View {
    @State var showingPassword = false
    @Binding var passphrase: String
    @State var disabled = false
    
    var body: some View {
        HStack {
            Text ("Passphrase")
            if showingPassword {
                TextField ("•••••••", text: $passphrase)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .disabled(disabled)
            } else {
                SecureField ("•••••••", text: $passphrase)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .disabled(disabled)
            }
            Button (action: {
                self.showingPassword.toggle ()
            }, label: {
                Image(systemName: self.showingPassword ? "eye" : "eye.slash")
                
            })
        }
    }
}

struct Passphrase_Previews: PreviewProvider {
    @State static var passphrase = "secret"
    
    static var previews: some View {
        VStack {
            Passphrase(passphrase: Passphrase_Previews.$passphrase)
            Passphrase(showingPassword: true, passphrase: Passphrase_Previews.$passphrase)
        }
    }
}
