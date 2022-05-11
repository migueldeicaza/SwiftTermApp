//
//  Hosts.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

func getHostImage (forKind hostKind: String) -> some View
{
    if hostKind == "" {
        return Image (systemName: "desktopcomputer")
        .scaledToFit()
        .frame(width: 28, height: 28)
    } else {
        return Image (hostKind)
        .resizable()
        .scaledToFit()
        .frame(width: 28, height: 28)
    }
}

struct HostSummaryView: View {
    @Binding var host: Host
    @State var showingModal = false
    @State var createNewTerm = false
    //@Environment(\.editMode) var editMode
    @State var active = false
    
    var body: some View {
        NavigationLink (destination: ConfigurableUITerminal(host: host, createNew: createNewTerm), isActive: $active) {
            
            HStack (spacing: 12){
                getHostImage (forKind: host.hostKind)
                    .font (.system(size: 28))
                    .foregroundColor(.primary)
                    .brightness(Connections.lookupActiveSession(host: self.host) != nil ? 0 : 0.6)
                    //.colorMultiply(Color.white)
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text ("\(host.alias)")
                            .bold()
                            .foregroundColor(.primary)
                        Spacer ()
                    }
                    Text (host.summary ())
                        //.brightness(0.4)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                Image (systemName: "square.and.pencil")
                    .font(.system(size: 24))
                    .foregroundColor(Color.accentColor)
                .onTapGesture {
                    self.showingModal = true
                }
                .accessibilityAction {
                    self.showingModal = true
                }
                .accessibilityLabel("Edit settings")
            }.sheet(isPresented: $showingModal) {
                HostEditView(host: self.host, showingModal: self.$showingModal)
            }
            .contextMenu {
                HStack {
                    Button(action: {
                        createNewTerm = true
                        active = true
                    }) {
                        Text("New Terminal")
                        Image(systemName: "plus.circle")
                    }
                }
//                Button(action: {
//                    print ("wussup")
//                }) {
//                    Text("Close Connection")
//                    Image(systemName: "minus.circle")
//                }
            }
        }
        .onAppear {
            createNewTerm = false
        }
    }
}

struct iPadHostSummaryView: View {
    @Binding var host: Host
    @State var showingModal = false
    @State var createNewTerm = false
    //@Environment(\.editMode) var editMode
    @State var active = false
    var body: some View {
        VStack {
            HStack (spacing: 12){
                getHostImage (forKind: host.hostKind)
                    .font (.system(size: 28))
                    .brightness(Connections.lookupActiveSession(host: self.host) != nil ? 0 : 0.6)
                    //.colorMultiply(Color.white)
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text ("\(host.alias)")
                            .bold()
                        Spacer ()
                    }
                    Text (host.summary ())
                        .brightness(0.4)
                        .font(.footnote)
                }
                Button (action: {
                    //
                }) {
                    Image (systemName: "square.and.pencil")
                        .font(.system(size: 24))
                }
                .onTapGesture {
                    self.showingModal = true
                }
            }.sheet(isPresented: $showingModal) {
                HostEditView(host: self.host, showingModal: self.$showingModal)
            }
            .contextMenu {
                HStack {
                    Button(action: {
                        createNewTerm = true
                        active = true
                    }) {
                        Text("New Terminal")
                        Image(systemName: "plus.circle")
                    }
                }
//                Button(action: {
//                    print ("wussup")
//                }) {
//                    Text("Close Connection")
//                    Image(systemName: "minus.circle")
//                }
            }
            .onTapGesture {
                active.toggle()
            }
            if active {
                NavigationLink (destination: ConfigurableUITerminal(host: host, createNew: createNewTerm), isActive: $active) {
                    EmptyView ()
                }
            }
        }
        .onAppear {
            createNewTerm = false
        }
    }
}

struct HostsView : View {
    @State var showHostEdit: Bool = false
    @ObservedObject var store: DataStore = DataStore.shared
    //@State private var editMode = EditMode.inactive

    func delete (at offsets: IndexSet)
    {
        store.removeHosts (atOffsets: offsets)
        store.saveState()
    }
    
    private func move(source: IndexSet, destination: Int)
    {
        store.hosts.move (fromOffsets: source, toOffset: destination)
        store.saveState()
    }
    
    var body: some View {
        VStack {
            STButton (text: "Add Host", icon: "plus.circle") {
                self.showHostEdit = true
            }

            if store.hosts.count == 0 {
                HStack (alignment: .top){
                    Image (systemName: "desktopcomputer")
                        .font (.title)
                    Text ("Create a host to define a machine you want to connect to.")
                        .font (.body)
                }.padding ()
                Spacer ()
            } else {
                List {
                    Section {
                        ForEach(self.store.hosts.indices, id: \.self) { idx in
                            iPadHostSummaryView (host: self.$store.hosts [idx])
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                        //.environment(\.editMode, $editMode)
                    }
                }
                .listStyle(DefaultListStyle())
                .toolbar {
                    ToolbarItem (placement: .navigationBarTrailing) {
                        EditButton ()
                    }
                }
            }
        }
        .navigationTitle(Text("Hosts"))
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
