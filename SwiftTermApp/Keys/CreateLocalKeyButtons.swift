//
//  CreateLocalKeyButtons.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/13/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Security
import CryptoKit

//
// This either uses the secure enclave to store the key (which is limited to the
// EC key, or an RSA key.
//
struct CreateLocalKeyButtons: View {
    @State var showEnclaveGenerator = false
    @State var showLocalGenerator = false
    
    func generateLocalKey (_ type: KeyType, _ comment: String, _ passphrase: String)-> Key?
    {
        return KeyTools.generateKey (type: type, secureEnclaveKeyTag: "", comment: comment, passphrase: passphrase, inSecureEnclave: false)
    }

    var body: some View {
        VStack {
            if SecureEnclave.isAvailable {
                STButton(text: "Create Enclave Key", icon: "plus.circle")
                    .onTapGesture {
                        self.showEnclaveGenerator = true
                    }
            }

            STButton (text: "Create Key", icon: "plus.circle")
                .onTapGesture {
                    self.showLocalGenerator = true
                }
        }
        .sheet(isPresented: self.$showLocalGenerator) {
            GenerateKey (showGenerator: self.$showLocalGenerator,  generateKey: self.generateLocalKey)
        }
        .sheet(isPresented: self.$showEnclaveGenerator) {
            GenerateSecureEnclave (showGenerator: self.$showEnclaveGenerator)
        }
    }
}

struct CreateLocalKeyButtons_Previews: PreviewProvider {
    static var previews: some View {
        CreateLocalKeyButtons()
    }
}
