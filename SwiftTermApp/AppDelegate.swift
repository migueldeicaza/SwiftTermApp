//
//  AppDelegate.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import UIKit
import SwiftUI


struct TerminalCommands: Commands {
    // To use this, read: https://developer.apple.com/forums/thread/651748
    // @FocusedBinding(\.selectedTerminal) var selectedTerminal: Terminal?
    
    
    var body: some Commands {
        CommandMenu ("Title") {
            Section {
                Button ("Soft Reset", action: {
                    guard let current = AppTerminalView.currentTerminalView else { return }
                    current.getTerminal().softReset()
                }).keyboardShortcut(KeyEquivalent("r"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option])
                Button ("Hard Reset", action: {
                    guard let current = AppTerminalView.currentTerminalView else { return }
                    current.getTerminal().resetToInitialState()
                }).keyboardShortcut(KeyEquivalent("r"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option, .control])
            }
        }
    }
}

@main
struct SampleApp: App {
    @State var dates = [Date]()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            TerminalCommands ()
        }
        #if os(macOS)
        Settings {
            Text ("These are the macOS settings")
        }
        #endif
    }
}
