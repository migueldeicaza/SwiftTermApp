//
//  Hosts.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct HostSummaryView: View {
    @Binding var host: Host
    @State var showingModal = false
    
    var body: some View {
        NavigationLink (destination: Text ("Connecting....")) {
            HStack {
            
                Image (systemName: "desktopcomputer")
                Text ("\(host.alias)")
                Spacer ()
                Button (action: {
                    print ("Hello")
                }) {
                    Image (systemName: "ellipsis.circle")
                }
                .onTapGesture {
                    self.showingModal = true
                }
            }.sheet(isPresented: $showingModal) {
                HostEditView(host: self.$host, showingModal: self.$showingModal)
            }
        }
    }
}

struct Hosts: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @State var hostEdit = false
    @State var freshHost: Host = Host()
    
    func run ()
    {
        print ("Clicked")
    }
    var body: some View {
        List (store.hosts.indices) { idx in
            HostSummaryView(host: self.$store.hosts [idx])
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Hosts")
        .navigationBarItems(trailing: HStack {
            Button (action: {}) {
                Image (systemName: "square.and.pencil")
            }.padding ()
            Button (action: {
                self.hostEdit = true
            }) {
                Image (systemName: "plus")
            }.sheet(isPresented: self.$hostEdit) {
                HostEditView (host: self.$freshHost, showingModal: self.$hostEdit)
            }
        })
    }
}

struct PrimaryLabel: ViewModifier {
    func body(content: Content) -> some View {
        content.frame (width: 100, alignment: .leading)
    }
}

struct Hosts_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Hosts()
        }
    }
}
