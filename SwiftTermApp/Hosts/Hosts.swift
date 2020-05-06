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
        NavigationLink (destination: SwiftUITerminal(host: self.host)) {
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
                HostEditView(host: self.host, showingModal: self.$showingModal)
            }
        }
    }
}


struct HostsView : View {
    @State var showHostEdit: Bool = false
    @ObservedObject var store: DataStore = DataStore.shared
    @State private var editMode = EditMode.inactive

    func delete (at offsets: IndexSet)
    {
        store.hosts.remove(atOffsets: offsets)
        store.saveState()
    }
    
    private func move(source: IndexSet, destination: Int)
    {
        store.hosts.move (fromOffsets: source, toOffset: destination)
        store.saveState()
    }
    
    var body: some View {
        List {
            STButton (text: "Add Host", icon: "plus.circle")
                .onTapGesture { self.showHostEdit = true }

            Section {
                ForEach(self.store.hosts.indices, id: \.self) { idx in
                    HostSummaryView (host: self.$store.hosts [idx])
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
                .environment(\.editMode, $editMode)
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text("Hosts"))
        .navigationBarItems(trailing: HStack {
            Button (action: { self.showHostEdit = true }) {
                Image (systemName: "plus")
            }
            EditButton()
        })
        .sheet (isPresented: $showHostEdit) {
            HostEditView(host: Host(), showingModal: self.$showHostEdit)
        }
        
    }
}

struct PrimaryLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
        // content.frame (width: 100, alignment: .leading)
    }
}

struct Hosts_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HostsView()
        }
    }
}
