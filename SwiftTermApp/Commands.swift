//
//  Commands.swift
//  Implements the various handlers for keyboard commands
//
//  Created by Miguel de Icaza on 7/17/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SwiftTerm

func export (vc: UIViewController, data: Data, file: String){
    let tmpUrl = URL (fileURLWithPath: NSTemporaryDirectory() + file);
    do {
        try data.write(to: tmpUrl)
        let a = UIDocumentPickerViewController (forExporting: [tmpUrl], asCopy: true)
        
        a.allowsMultipleSelection = false
        
        vc.present(a, animated: true, completion: nil)
    } catch {
    }

}

// Shows a dialog box to export the contents
func currentTerminalExportContents () {
    guard let currentVC = TerminalViewController.visibleControler else { return }
    guard let data = currentVC.terminalView?.getTerminal().getBufferAsData() else { return }
    
    export (vc: currentVC, data: data, file: "/\(currentVC.host.alias)-terminal.txt")
}

func currentTerminalExportSelection () {
    guard let currentVC = TerminalViewController.visibleControler else { return }
    guard let str = currentVC.terminalView?.getSelection() else { return }
    guard let data = str.data(using: .utf8) else { return }
    
    export (vc: currentVC, data: data, file: "/\(currentVC.host.alias)-selection.txt")
}

struct TerminalCommands: Commands {
    // To use this, read: https://developer.apple.com/forums/thread/651748
    // @FocusedBinding(\.selectedTerminal) var selectedTerminal: Terminal?
    
    
    @CommandsBuilder var body: some Commands {
        CommandMenu (String (localized: "Terminal")) {
            Button (String (localized: "Export Text"), action: currentTerminalExportContents)
                .keyboardShortcut(KeyEquivalent("s"), modifiers: [.command])
            
            Button (String (localized: "Export Selection"), action: currentTerminalExportSelection)
                .keyboardShortcut(KeyEquivalent("s"), modifiers: [.shift, .command])

            Section {
                Button (String (localized: "Soft Reset"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.getTerminal().softReset()
                }).keyboardShortcut(KeyEquivalent("r"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option])
                
                Button (String (localized: "Hard Reset"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.getTerminal().resetToInitialState()
                }).keyboardShortcut(KeyEquivalent("r"), modifiers: [/*@START_MENU_TOKEN@*/.command/*@END_MENU_TOKEN@*/, .option, .control])
            }
        }

        CommandMenu (String (localized: "Keys ")) {
            Button (String (localized: "Escape"), action: {
                guard let current = TerminalViewController.visibleTerminal else { return }
                current.send([0x1b])
            }).keyboardShortcut(KeyEquivalent("["), modifiers: [.control])
            Button (String (localized:"F1"), action: {
                guard let current = TerminalViewController.visibleTerminal else { return }
                current.send(EscapeSequences.cmdF [0])
            }).keyboardShortcut(KeyEquivalent ("1"), modifiers: [.command, .shift])
            Button (String (localized:"F2"), action: {
                guard let current = TerminalViewController.visibleTerminal else { return }
                current.send(EscapeSequences.cmdF [1])
            }).keyboardShortcut(KeyEquivalent ("2"), modifiers: [.command, .shift])
            Button (String (localized:"F3"), action: {
                guard let current = TerminalViewController.visibleTerminal else { return }
                current.send(EscapeSequences.cmdF [2])
            }).keyboardShortcut(KeyEquivalent ("3"), modifiers: [.command, .shift])
            Button (String (localized:"F4"), action: {
                guard let current = TerminalViewController.visibleTerminal else { return }
                current.send(EscapeSequences.cmdF [3])
            }).keyboardShortcut(KeyEquivalent ("4"), modifiers: [.command, .shift])
            Button (String (localized:"F5"), action: {
                guard let current = TerminalViewController.visibleTerminal else { return }
                current.send(EscapeSequences.cmdF [4])
            }).keyboardShortcut(KeyEquivalent ("5"), modifiers: [.command, .shift])
            HStack {
                Button (String (localized:"F6"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.send(EscapeSequences.cmdF [5])
                }).keyboardShortcut(KeyEquivalent ("6"), modifiers: [.command, .shift])
                Button (String (localized:"F7"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.send(EscapeSequences.cmdF [6])
                }).keyboardShortcut(KeyEquivalent ("7"), modifiers: [.command, .shift])
                Button (String (localized:"F8"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.send(EscapeSequences.cmdF [7])
                }).keyboardShortcut(KeyEquivalent ("8"), modifiers: [.command, .shift])
                Button (String (localized:"F9"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.send(EscapeSequences.cmdF [8])
                }).keyboardShortcut(KeyEquivalent ("9"), modifiers: [.command, .shift])
                Button (String (localized:"F10"), action: {
                    guard let current = TerminalViewController.visibleTerminal else { return }
                    current.send(EscapeSequences.cmdF [9])
                }).keyboardShortcut(KeyEquivalent ("0"), modifiers: [.command, .shift])
            }
        }
    }
}
