//
//  AppDelegate.swift
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Instabug

@main
struct SampleApp: App {
    @State var dates = [Date]()
    @State var launchHost: Host?
    
    init () {
        Instabug.start(withToken: "CHANGE_ME", invocationEvents: [.floatingButton, .screenshot])
        BugReporting.floatingButtonEdge = .maxXEdge
        BugReporting.floatingButtonTopOffset = UIScreen.main.bounds.height - 125
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
