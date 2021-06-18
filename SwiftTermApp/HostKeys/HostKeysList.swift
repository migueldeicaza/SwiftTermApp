//
//  HostKeysList.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/17/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct HostKeysList: View {
    @ObservedObject var store: DataStore = DataStore.shared

    var body: some View {
        List {
            ForEach (store.knownHosts) { record in
                VStack (alignment: .leading) {
                    HStack {
                        Text ("Endpoint:")
                        Spacer ()
                        Text ("\(record.host)")
                    }
                    HStack {
                        Text ("Key Type:")
                        Spacer ()
                        Text ("\(record.keyType)")
                    }
                    Text ("Key:")
                    Text ("\(record.key)")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        
                }
            }
            .onDelete(perform: delete)
        }
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    func delete (at offsets: IndexSet) {
        DataStore.shared.knownHosts.remove(atOffsets: offsets)
        DataStore.shared.saveKnownHosts()
    }
}

struct HostKeysList_Previews: PreviewProvider {
    static var previews: some View {
        HostKeysList()
    }
}
