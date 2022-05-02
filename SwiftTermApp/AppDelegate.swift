//
//  AppDelegate.swift
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Shake
var globalHistoryController = HistoryController()

@main
struct SampleApp: App {
    @State var dates = [Date]()
    @State var launchHost: Host?
    @StateObject private var historyController = globalHistoryController
    @Environment(\.scenePhase) var scenePhase

    func extendLifetime () {
        // Attempts to keep the app alive, so our sockets are not killed within one second of going into the background
        var backgroundHandle: UIBackgroundTaskIdentifier? = nil
        backgroundHandle = UIApplication.shared.beginBackgroundTask(withName: "lifetime extender") {
            if let handle = backgroundHandle {
                UIApplication.shared.endBackgroundTask(handle)
            }
        }
    }
    init () {
        if shakeKey != "" {
            Shake.start(clientId: shakeId, clientSecret: shakeKey)
        }
        if settings.locationTrack {
            locationTrackerStart()
        }
//        for family in UIFont.familyNames.sorted() {
//            let names = UIFont.fontNames(forFamilyName: family)
//            print("Family: \(family) Font names: \(names)")
//        }
//        print ("here")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    if Connections.shared.connections.count > 0 {
                        locationTrackerResume()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    locationTrackerSuspend()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        extendLifetime ()
                    }
                }
                .environment(\.managedObjectContext, historyController.container.viewContext)
        }
        .commands {
            TerminalCommands()
        }
        #if os(macOS)
        Settings {
            Text ("These are the macOS settings")
        }
        #endif
    }
}
