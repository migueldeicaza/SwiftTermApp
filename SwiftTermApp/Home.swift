//
//  ContentView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

private let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

struct ContentView: View {
    @State private var dates = [Date]()

    var body: some View {
        NavigationView {
            HomeView(dates: $dates)
                .navigationBarTitle(Text("SwiftTerm"))
                .navigationBarItems(
                    leading: EditButton(),
                    trailing: Button(
                        action: {
                            withAnimation { self.dates.insert(Date(), at: 0) }
                        }
                    ) {
                        Image(systemName: "plus")
                    }
                )
            DetailView()
        }.navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
}


struct HostsView : View {
    @State var showHostEdit: Bool = false
    @ObservedObject var store: DataStore = DataStore.shared
    
    func newHost ()
    {
        
    }
    var body: some View {
        List {
            Section {
                ForEach(self.store.hosts.indices) { idx in
                    HostSummaryView (host: self.$store.hosts [idx])
                }
            }
        }.listStyle(GroupedListStyle())
        .navigationBarTitle(Text("Hosts"))
        .navigationBarItems(trailing: Button (action: {
            self.showHostEdit = true
        }) {
            Image (systemName: "plus")
        })
        .sheet (isPresented: $showHostEdit) {
            //HostEditView(showingModal: self.$showHostEdit).frame(width: 300, height: 200)
            Text ("Hosts Editing Goes here")
        }
    }
}

struct HomeView: View {
    @Binding var dates: [Date]
    @ObservedObject var store: DataStore = DataStore.shared

    func sortDate (first: Host, second: Host) throws -> Bool
    {
        first.lastUsed > second.lastUsed
    }
    
    var body: some View {
        List {
            Section (header: Text ("Recent")) {
                ForEach(self.store.recentIndices ()) { idx in
                    HostSummaryView (host: self.$store.hosts [idx])
                }
            }
            Section {
                NavigationLink(
                    destination: HostsView()
                ) {
                    Text("Hosts")
                }
                NavigationLink(
                    destination: SessionsView()
                ) {
                    Text("Sessions")
                }
                NavigationLink(
                    destination: KeyManagementView( )
                ) {
                    Text("Keys")
                }
                NavigationLink(
                    destination: SettingsView()
                ) {
                    Text("Settings")
                }
            }
        }.listStyle(GroupedListStyle())
    }
}

struct DetailView: View {
    var body: some View {
        Group {
            Text("Detail view content goes here")
        }.navigationBarTitle(Text("Detail"))
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
