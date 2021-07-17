//
//  AppDelegate.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

func currentTerminalExportContents () {
    guard let currentVC = TerminalViewController.visibleControler else { return }
    guard let data = currentVC.terminalView?.getTerminal().getBufferAsData() else { return }
    
    let tmpUrl = URL (fileURLWithPath: NSTemporaryDirectory() + "/\(currentVC.host.alias)-terminal.txt");
    do {
        try data.write(to: tmpUrl)
        let a = UIDocumentPickerViewController (forExporting: [tmpUrl], asCopy: true)
        
        a.allowsMultipleSelection = false
        
        currentVC.present(a, animated: true, completion: nil)
    } catch {
    }
}

struct TerminalCommands: Commands {
    // To use this, read: https://developer.apple.com/forums/thread/651748
    // @FocusedBinding(\.selectedTerminal) var selectedTerminal: Terminal?
    
    
    @CommandsBuilder var body: some Commands {
        CommandGroup (after: CommandGroupPlacement.textEditing) {
            Button ("Export Text As", action: currentTerminalExportContents)
                .keyboardShortcut(KeyEquivalent("s"), modifiers: [.command])
            
            Button ("Paste Special", action: {
                print ("TODO")
            }).keyboardShortcut(KeyEquivalent("k"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option, .control])
        }
        CommandMenu ("Terminal") {
            Section {
                Button ("Escape", action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.send([0x1b])
                }).keyboardShortcut(KeyEquivalent("`"), modifiers: [.command])
                Button ("Soft Reset", action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.getTerminal().softReset()
                }).keyboardShortcut(KeyEquivalent("r"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option])
                
                Button ("Hard Reset", action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.getTerminal().resetToInitialState()
                }).keyboardShortcut(KeyEquivalent("r"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option, .control])
                
                Button ("F1", action: {
                    
                }).keyboardShortcut(KeyboardShortcut ("0"))
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
            TerminalCommands()
        }
        #if os(macOS)
        Settings {
            Text ("These are the macOS settings")
        }
        #endif
    }
}
