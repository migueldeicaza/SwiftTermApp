//
//  AppDelegate.swift
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Instabug
var globalHistoryController = HistoryController()

@main
struct SampleApp: App {
    @State var dates = [Date]()
    @State var launchHost: Host?
    @StateObject private var historyController = globalHistoryController

    init () {
        if instabugKey != "" {
            Instabug.start(withToken: instabugKey, invocationEvents: [.shake, .screenshot])
            Instabug.welcomeMessageMode = IBGWelcomeMessageMode.beta

            // "beta" mode messages
            Instabug.setValue(
                "Welcome to the SwiftTermApp beta!", forStringWithKey: kIBGBetaWelcomeMessageWelcomeStepTitle)
            Instabug.setValue(
                "Thanks for helping us improve SwiftTermApp. We are looking forward to hearing your feedback.", forStringWithKey: kIBGBetaWelcomeMessageWelcomeStepContent)
            
            Instabug.setValue(
                "How to report a bug?", forStringWithKey: kIBGBetaWelcomeMessageHowToReportStepTitle)
            Instabug.setValue(
                "Shake your device or use the 'Support' menu option to report a bug or to share feedback or a feature request.", forStringWithKey: kIBGBetaWelcomeMessageHowToReportStepContent)
            
            Instabug.setValue(
                "Happy SSHing!", forStringWithKey: kIBGBetaWelcomeMessageFinishStepTitle)
            Instabug.setValue(
                "We're hard at work on the next SwiftTermApp release. Be sure to check TestFlight for new releases to make sure you're getting the best experience.", forStringWithKey: kIBGBetaWelcomeMessageFinishStepContent)

        }
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
