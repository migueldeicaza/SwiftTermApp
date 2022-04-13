//
//  HostKeysList.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/17/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct Explanation: View {
    @Binding var shown: Bool
    
    var body: some View {
        NavigationView {
            VStack (alignment: .leading){
                Text ("SwiftTermApp remembers the keys that each host you have connected to uses.   These keys are used to ensure that you do not accidentally log into a malicious host that can steal information from you.\n\nIn some scenarios, when a computer system is reinstalled the keys might change, and you might want to consider removing it from the list of known hosts.\n\nYou can use the fingerprint to visually inspect if the key matches the host you are trying to connect to.")
                Spacer ()
            }
            .padding()
            
            .toolbar {
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button ("Dismiss") {
                        self.shown = false
                    }
                }
            }
        }
    }
}
struct HostKeysList: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @State var showInfo = false
    
    var body: some View {
        VStack {
            if store.knownHosts.count == 0 {
                HStack (alignment: .top){
                    Image (systemName: "lock.desktopcomputer")
                        .font (.title)
                    Text ("The lists of hosts you have connected to, along with their fingerprints will be listed here.   These fingerprints are checked on each connection to ensure that a machine is not swapped behind your back and you get tricked into logging into a machine controlled by an adversary")
                        .font (.body)
                }.padding ()
                Spacer ()
                
            } else {
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
            }
        }
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                Button (action: { self.showInfo = true }) {
                    Image(systemName: "info.circle")
                }
            }
            ToolbarItem (placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: self.$showInfo) { Explanation (shown: self.$showInfo) }
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
