//
//  ContentView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Shake
import Introspect
import CoreData

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
    @State var controller: UISplitViewController?
    @State var savedMode: UISplitViewController.DisplayMode = .automatic
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationView {
            HomeView ()
            
            DefaultHomeView ()
        }.introspectSplitViewController { x in
            controller = x
            savedMode = x.displayMode
        }.onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                if let c = controller {
                    c.preferredDisplayMode = savedMode
                }
                
                break
            case .inactive:
                break
            case .background:
                savedMode = controller?.displayMode ?? UISplitViewController.DisplayMode.automatic
                break
            default:
                break
            }
        }

    }
}

// Given a URL in the form handler://[username@]host[:port] return a Host that matches
// it.   If we have a known host that shares the port
func getHostFromUrl (_ url: URL, visiblePrefix: String = "Dynamic") -> Host? {
    let requestedPort = url.port ?? 22
    let requestedUser = url.user
    
    if let requestedHost = url.host {
        let hr = CHost.fetchRequest()
        if let withUser = requestedUser {
            hr.predicate = NSPredicate (format: "sHostname == %@ && sPort == %@ && sUsername == %@", requestedHost, requestedPort, withUser)
        } else {
            hr.predicate = NSPredicate (format: "sHostname == %@ && sPort == %@", requestedHost, requestedPort)
        }
        hr.fetchLimit = 1
        if let match = try? globalDataController.container.viewContext.fetch(hr).first {
            return match
        }
        
        return MemoryHost (
            id: UUID(),
            alias: "\(visiblePrefix) \(requestedHost)",
            hostname: requestedHost,
            backspaceAsControlH: false,
            port: requestedPort,
            usePassword: false,
            username: requestedUser ?? "",
            password: "",
            hostKind: "",
            environmentVariables: [:],
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

func getFirstRun () -> Bool {
    let key = "launchedBefore"
    let ran = UserDefaults.standard.bool(forKey: key)
    UserDefaults.standard.set (true, forKey: key)
    return !ran
}

struct HomeView: View {
    @ObservedObject var connections = Connections.shared
    @Environment(\.scenePhase) var scenePhase
    @State var launchHost: Host? = nil
    @State var transientLaunch: Bool? = false
    @State var firstRun = getFirstRun ()
    @State var terminalCount = 0

    @FetchRequest (sortDescriptors: [SortDescriptor (\CHost.sLastUsed, order: .reverse)], predicate: NSPredicate (format: "sLastUsed != nil"))
    var hosts: FetchedResults<CHost>

    init () {
        let request: NSFetchRequest<CHost> = CHost.fetchRequest()

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CHost.sLastUsed, ascending: false)
        ]
        request.predicate = NSPredicate (format: "sLastUsed != nil")
        request.fetchLimit = 3
        _hosts = FetchRequest(fetchRequest: request)
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
            if hosts.count > 0 {
                Section (header: Text ("Recent")) {
                    
                    RecentHostsView()
                    if transientLaunch ?? false == true {
                        NavigationLink ("Dynamic Launch", destination: ConfigurableUITerminal(host: launchHost, createNew: true), tag: true, selection: $transientLaunch)
                    }
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
                        Label("Terminals", systemImage: "terminal")
                        Spacer ()
                        Text ("\(terminalCount)")
                            .padding(4)
                            .background(Color (.systemGray5))
                            .cornerRadius(3)
                            .foregroundColor(Color (.systemGray))
                            .onAppear {
                                terminalCount = connections.terminalsCount
                            }
                    })
                NavigationLink(
                    destination: KeyManagementView(),
                    label: {
                        Label("Keys", systemImage: "key")
                    })
                NavigationLink(
                    destination: HostKeysList (),
                    label: {
                        Label("Known Hosts", systemImage: "lock.desktopcomputer")
                    })
                NavigationLink(
                    destination: SnippetBrowser(),
                    label: {
                        Label ("Snippets", systemImage: "note.text")
                    })
                NavigationLink(
                    destination: SettingsView(),
                    label: {
                        Label("Settings", systemImage: "gear")
                    })
                NavigationLink(
                    
                    destination: HistoryView(),
                    label: {
                        Label("History", systemImage: "clock")
                    })

            }
            
            Section {
                NavigationLink(
                    destination: CreditsView(),
                    label: {
                        Label("Credits", systemImage: "info.circle")
                    })
                Button (
                    action: { Shake.show(.home) },
                    label: {
                        Label("Support", systemImage: "questionmark.circle")
                    })
            }
            
            #if DEBUG
            if FileManager.default.fileExists(atPath: "/tmp/enable-dangerous-diagnostics") {
                Section {
                    Button ("Diagnostics - Dump State (DANGEROUS, EXPOSES CONFIDENTIAL DATA in /TMP DUMP) ") {
                        DataStore.shared.dumpData ()
                    }
                    Button ("Clear all KeyChain Elements") {
                        KeyTools.reset ()
                    }
                }
            }
            #endif
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
            var host = getHostFromUrl (url)
            if host == nil { return }
            
            if host!.username == "" {
                if let window = getCurrentKeyWindow(), let vc = window.rootViewController {
                    Task {
                        if let user = await promptMissingUser (vc) {
                            host!.username = user
                            launch (host!)
                        }
                    }
                }
            } else {
                launch (host!)
            }
        }
        .sheet (isPresented: $firstRun) {
            OnboardWelcome (showOnboarding: $firstRun)
        }
        .navigationBarTitle("Home")
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
