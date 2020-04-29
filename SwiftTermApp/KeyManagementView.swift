//
//  KeyManagementView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct Key: Codable, Identifiable {
    let id = UUID()
    var type: String = ""
    var name: String = ""
    var privateKey: String = ""
    var publicKey: String = ""
    var password: String = ""
}

struct KeyManagementView: View {
    @State var key: Key
    
    var body: some View {
        List {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "lock")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24)
                    .padding(8)
                VStack (alignment: .leading) {
                    Text ("\(key.name)")
                        .font(.title)
                    Text ("Key Type: \(key.type)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }.cornerRadius(10)
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Keys")
    }
}

struct KeyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        KeyManagementView(key: Key(type: "RSA 2048", name: "iPhone 2018 Key", privateKey: "XX", publicKey: "XX", password: "XX"))
    }
}
