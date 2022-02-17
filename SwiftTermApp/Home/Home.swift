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
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    @ObservedObject var store: DataStore = DataStore.shared

    var body: some View {
#if os(iOS)
        if horizontalSizeClass == .compact {
            CompactHomeView()
        } else {
            LargeHomeView()
        }
#else
        LargeHomeView()
#endif
    }
}

struct CompactHomeView: View {
    var body: some View {
        NavigationView {
            HomeView()
                .navigationTitle(Text("SwiftTerm"))
            DefaultHomeView()
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct LargeHomeView: View {
    
    var body: some View {
        NavigationView {
            HomeView ()
            DefaultHomeView ()
        }
    }
}

struct HomeView: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @ObservedObject var connections = Connections.shared
    @Environment(\.scenePhase) var scenePhase

    func sortDate (first: Host, second: Host) throws -> Bool
    {
        first.lastUsed > second.lastUsed
    }
    
    var body: some View {
        List {
            //QuickLaunch()
            Section (header: Text ("Recent")) {
                ForEach(self.store.recentIndices (), id: \.self) { idx in
                    HostSummaryView (host: self.$store.hosts [idx])
                }
            }
            Section {
                NavigationLink(
                    destination: HostsView(),
                    label: {
                        Label("Hosts", systemImage: "desktopcomputer")
                    })
                NavigationLink(
                    destination: SessionsView(),
                    label: {
                        Label("Sessions", systemImage: "terminal")
                        Spacer ()
                        Text ("\(connections.connections.count)")
                            .padding(4)
                            .background(Color (.systemGray5))
                            .cornerRadius(3)
                            .foregroundColor(Color (.systemGray))
                    })
                NavigationLink(
                    destination: KeyManagementView( ),
                    label: {
                        Label("Keys", systemImage: "key")
                    })
                NavigationLink(
                    destination: HostKeysList (),
                    label: {
                        Label("Known Host Keys", systemImage: "lock.desktopcomputer")
                    })
                NavigationLink(
                    destination: SettingsView(),
                    label: {
                        Label("Settings", systemImage: "gear")
                    })
            }
            
            Section {
                NavigationLink(
                    destination: CreditsView(),
                    label: {
                        Label("Credits", systemImage: "info.circle")
                    })
            }
        }
        .listStyle(GroupedListStyle())
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                break
            case .inactive:
                break
            case .background:
                //Connections.saveState()
                break
            default:
                break
            }
        }
        //.listStyle(.sidebar)

    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        CompactHomeView()
            .previewDevice(PreviewDevice(rawValue: "iPhone 12"))
        LargeHomeView()
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (5th generation)"))
    }
}
