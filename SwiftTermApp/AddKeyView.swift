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
    @State var name: String = ""
    @State var privateKey: String = ""
    @State var publicKey: String = ""
    @State var password: String = ""
    
    var disableSave: Bool {
        name == "" || privateKey == ""
    }
    
    var body: some View {
        NavigationView {
            List {
                Section (header: Text ("Settings")){
                    VStack (alignment: .leading){
                        Text ("Name")
                        TextField ("Required", text: self.$name)
                    }
                    VStack (alignment: .leading) {
                        Text ("Private Key").modifier(PrimaryLabel())
                        TextField ("Required", text: self.$privateKey)
                    }
                    VStack (alignment: .leading) {
                        Text ("Public Key").modifier(PrimaryLabel())
                        TextField ("Optional", text: self.$publicKey)
                    }
                    
                    VStack (alignment: .leading){
                        Text ("Password")
                        HStack {
                            TextField ("Optional", text: self.$password)
                            Button (action: {}, label: {
                                Text ("SHOW").foregroundColor(Color (UIColor.link))
                                
                            })
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle ())
            .navigationBarItems(
                leading:  Button ("Cancel") {},
                trailing: Button("Save") {
                
                }.disabled (disableSave))
        }
        
    }
}

struct PasteKey_Previews: PreviewProvider {
    
    static var previews: some View {
        Text ("").sheet(isPresented: .constant (true)) {
            AddKeyView()
        }
    }
}
