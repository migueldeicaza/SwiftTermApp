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

// Given a URL in the form handler://[username@]host[:port] return a Host that matches
// it.   If we have a known host that shares the port
func getHostFromUrl (_ url: URL, visiblePrefix: String = "Dynamic") -> Host? {
    let requestedPort = url.port ?? 22
    let requestedUser = url.user
    
    if let requestedHost = url.host {
        let matches = DataStore.shared.hosts.filter ({ h in
            h.hostname == requestedHost && h.port == h.port && (requestedUser != nil ? requestedUser == h.username : true)
        })
        if let match = matches.first {
            return match
        }
        
        return Host (id: UUID(),
                     alias: "\(visiblePrefix) \(requestedHost)",
                     hostname: requestedHost,
                     backspaceAsControlH: false,
                     port: requestedPort,
                     usePassword: false,
                     username: requestedUser ?? "",
                     password: "",
                     hostKind: "",
                     environmentVariables: [],
                     startupScripts: [],
                     sshKey: nil,
                     style: "",
                     background: "",
                     lastUsed: Date ())
    }
    return nil
}

func getMissingUserPrompt (done: @escaping (_ result: String?) -> ()) -> UIAlertController {
    let alert = UIAlertController (title: "Username", message: "The request to open the url did not include a username, please provide it here", preferredStyle: .alert)
    alert.addTextField { tf in
        tf.placeholder = ""
        tf.keyboardType = .alphabet
    }
    let cancel = UIAlertAction(title: "Cancel", style: .default) { action in
        done (nil)
    }
    alert.addAction (cancel)
    let ok = UIAlertAction(title: "Ok", style: .default) { action in
        let textField = alert.textFields?.first
        done (textField?.text ?? nil)
    }
    alert.addAction (ok)
    return alert
}

// prompts for a username when it is missing
@MainActor
func promptMissingUser (_ parentController: UIViewController) async -> String? {
    
    let result: String? = await withCheckedContinuation { c in
        let alert = getMissingUserPrompt { result in
            c.resume(returning: result)
        }
        parentController.present(alert, animated: true, completion: nil)
    }
    
    return result
}

/// getCurrentKeyWindow: returns the current key window from the application
@MainActor
func getCurrentKeyWindow () -> UIWindow? {
    return UIApplication.shared.connectedScenes
          .filter { $0.activationState == .foregroundActive }
          .map { $0 as? UIWindowScene }
          .compactMap { $0 }
          .first?.windows
          .filter { $0.isKeyWindow }
          .first
}

struct HomeView: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @ObservedObject var connections = Connections.shared
    @Environment(\.scenePhase) var scenePhase
    @State var launchHost: Host? = nil
    @State var transientLaunch: Bool? = false
    
    func sortDate (first: Host, second: Host) throws -> Bool
    {
        first.lastUsed > second.lastUsed
    }
    
    // Launches the specified host as a terminal, used in response to openUrl requests
    @MainActor
    func launch (_ host: Host) {
        launchHost = host
        transientLaunch = true
    }
    
    var body: some View {
        List {
            //QuickLaunch()
            Section (header: Text ("Recent")) {
                ForEach(self.store.recentIndices (), id: \.self) { idx in
                    HostSummaryView (host: self.$store.hosts [idx])
                }
                if transientLaunch ?? false == true {
                    NavigationLink ("Dynamic Launch", destination: ConfigurableUITerminal(host: launchHost, createNew: true), tag: true, selection: $transientLaunch)
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
                        Label("Known Host", systemImage: "lock.desktopcomputer")
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
        .onOpenURL { url in
            if let host = getHostFromUrl (url) {
                if host.username == "" {
                    if let window = getCurrentKeyWindow(), let vc = window.rootViewController {
                        Task {
                            if let user = await promptMissingUser (vc) {
                                host.username = user
                                launch (host)
                            }
                        }
                    }
                } else {
                    launch (host)
                }
            }
        }
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
