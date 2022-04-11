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

            NetworkLogger.enabled = false
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
