//
//  GenerateSecureEnclave.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/12/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

let secureEnclaveKeyTag = "SwiftTermSecureEnclaveKeyTag"

struct GenerateSecureEnclave: View {
    @EnvironmentObject var dataController: DataController
    @Environment(\.managedObjectContext) var moc
    @State var title = "SwiftTerm Enclave Key on \(UIDevice.current.name)"
    @Binding var showGenerator: Bool
    @State var showAlert: Bool = false
    
    // Externally settable
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
    
    func callGenerateKey ()
    {
        if let generated = KeyTools.generateKey (type: .ecdsa(inEnclave:true), secureEnclaveKeyTag: secureEnclaveKeyTag, comment: title, passphrase: "") {
            let _ = CKey (context: moc, blueprint: generated)
            dataController.save ()
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section (header: Text ("Secure Enclave Key")) {
                        HStack {
                            Text ("Type")
                            Spacer ()
                            Text ("ecdsa-sha2-nistp256")
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text ("Private Key Storage")
                            Spacer ()
                            Text ("Secure Enclave")
                                .foregroundColor(.gray)
                        }

                    }
                    Section {
                        VStack (alignment: .leading) {
                            Text ("Comment")
                            TextField ("", text: self.$title)
                                
                        }
                    }
                }
                .listStyle(GroupedListStyle ())
            }
            .environment(\.horizontalSizeClass, .regular)
            .toolbar {
                ToolbarItem (placement: .navigationBarLeading) {
                    Button ("Cancel") {
                        self.showGenerator = false
                    }
                }
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button("Generate") {
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
    }
}

struct GenerateSecureEnclave_Previews: PreviewProvider {
    static var previews: some View {
        GenerateSecureEnclave(showGenerator: .constant(true))
    }
}
