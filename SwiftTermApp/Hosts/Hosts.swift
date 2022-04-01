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
    @State var compact = false
    
    //@Environment(\.editMode) var editMode
    @State var active = false
    var body: some View {
        
        HStack (spacing: 12){
            getHostImage (forKind: host.hostKind)
                .font (.system(size: 28))
                .brightness(Connections.lookupActive(host: self.host) != nil ? 0 : 0.6)
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
                    Text("New Connection")
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
        .onAppear {
            createNewTerm = false
        }
        .padding(.horizontal, compact ? 0 : nil)
    
        if active {
            NavigationLink (destination: ConfigurableUITerminal(host: host, createNew: createNewTerm), isActive: $active) {
                EmptyView()
            }
        }
    }
}



struct HostsView : View {
    @State var showHostEdit: Bool = false
    @ObservedObject var store: DataStore = DataStore.shared
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
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
            STButton (text: "Add Host", icon: "plus.circle")
                .onTapGesture { self.showHostEdit = true }
            
            Section {
                if horizontalSizeClass == .compact {
                    List {
                        ForEach(self.store.hosts.indices, id: \.self) { idx in
                            HostSummaryView (host: self.$store.hosts [idx], compact: true)
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                        
                    }
                } else {
                    LazyVGrid (columns: [ GridItem (.adaptive(minimum: 300))], spacing: 0) {
                        ForEach(self.store.hosts.indices, id: \.self) { idx in
                            HostSummaryView (host: self.$store.hosts [idx], compact: false)
                                .padding()
                                .background(Color.secondary.opacity(0.1))

                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                }
                //.environment(\.editMode, $editMode)
            }
        }
        .listStyle(DefaultListStyle())
        .navigationTitle(Text("Hosts"))
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                EditButton ()
            }
        }
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
