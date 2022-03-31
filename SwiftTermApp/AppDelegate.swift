//
//  AppDelegate.swift
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

var globalHistoryController = HistoryController()

@main
struct SampleApp: App {
    @State var dates = [Date]()
    @State var launchHost: Host?
    @StateObject private var historyController = globalHistoryController

    init () {
        if settings.locationTrack {
            locationTrackerStart()
        }
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
