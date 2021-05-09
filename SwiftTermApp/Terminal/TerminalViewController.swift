//
//  TerminalViewController.swift
//
//  This view controller can be used for any TerminalViews (currently just SshTerminalView, but hopefully a Mosh one later)
//
//  Created by Miguel de Icaza on 5/5/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftTerm
import SwiftUI

///
/// Implements the host for the TerminalView and takes care of the keyboard showing/hiding
/// as well as screenshotting the current session, so it can be used elsewhere
///
/// This can be constructed either with a Host, to trigger the connection workflow, or with a
/// TerminalView to become the host for an existing view.
///
class TerminalViewController: UIViewController {
    // If this is nil, it will trigger the SSH workflow.
    var terminalView: SshTerminalView?
    var interactive: Bool
    var host: Host
    var serial: Int
    static var Serial: Int = 0

    // Because we are sharing the TerminalView, we do not want to
    // mess with its size, unless we have it attached to this view
    func isTerminalViewAttached () -> Bool {
        if let t = terminalView {
            return view.subviews.contains(t)
        }
        return false
    }
    
    // This constructor is used to launch a new instance, and will trigger the SSH workflow
    init (host: Host, interactive: Bool)
    {
        serial = TerminalViewController.Serial
        TerminalViewController.Serial += 1
        self.host = host
        self.interactive = interactive
        DataStore.shared.used (host: host)
        super.init(nibName: nil, bundle: nil)
    }

    // This consturctor is used to create a fresh TerminalViewController from an existing TerminalView
    init (terminalView: SshTerminalView, interactive: Bool)
    {
        serial = TerminalViewController.Serial
        TerminalViewController.Serial += 1
        self.terminalView = terminalView
        self.host = terminalView.host
        self.interactive = interactive
        DataStore.shared.used (host: host)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startConnection() -> SshTerminalView? {
        do {
            let tv = try SshTerminalView(frame: view.frame, host: host)
            if host.style == "" {
                tv.applyTheme (theme: settings.getTheme())
            } else {
                tv.applyTheme(theme: settings.getTheme(themeName: host.style))
            }
            tv.feed(text: "Welcome to SwiftTerm\r\n\n")
            return tv
        } catch MyError.noValidKey(let msg) {
            terminalViewCreationError (msg)
        } catch {
            terminalViewCreationError ("general")
        }
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        if terminalView == nil {
            terminalView = startConnection()
        }
        guard let t = terminalView else {
            return
        }
        // if it succeeded
        self.terminalView = t
        t.frame = view.frame
        t.translatesAutoresizingMaskIntoConstraints = true
        t.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(t)
        
        if let ml = t.metalLayer {
            view.layer.insertSublayer(ml, at: 0)
        }
        if interactive {
            t.becomeFirstResponder()
        } else {
            let _ = t.resignFirstResponder()
        }
        Connections.track(connection: t)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !interactive && isTerminalViewAttached () {
            terminalView!.frame = view.frame
        }
    }
    func terminalViewCreationError (_ msg: String)
    {
        let alert = UIAlertController(title: "Connection Problem", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            NSLog("The \"OK\" alert occured.")
        }))
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
}

typealias Controller = TerminalViewController

//
// This is the wrapper to use the TerminalViewController in Swift
//
final class SwiftUITerminal: NSObject, UIViewControllerRepresentable, UIDocumentPickerDelegate {
    var terminalView: SshTerminalView?
    typealias UIViewControllerType = TerminalViewController
    
    enum Kind {
        case host (host: Host, createNew: Bool)
        case rehost (rehost: SshTerminalView)
    }
    
    var kind: Kind
    var interactive: Bool
    
    init (host: Host, createNew: Bool, interactive: Bool)
    {
        kind = .host(host: host, createNew: createNew)
        self.interactive = interactive
    }
    
    init (existing: SshTerminalView, interactive: Bool)
    {
        self.terminalView = existing
        kind = .rehost(rehost: existing)
        self.interactive = interactive
        super.init ()
    }

    func rehost ()
    {
        if let tv = terminalView {
            viewController.view.addSubview(tv)
        }
    }
    
    var viewController: TerminalViewController!

    func makeUIViewController(context: UIViewControllerRepresentableContext<SwiftUITerminal>) -> TerminalViewController {
        
        switch kind {
        case .host(host: let host, createNew: let createNew):
            if !createNew {
                if let v = Connections.lookupActive(host: host) {
                    viewController = TerminalViewController(terminalView: v, interactive: interactive)
                    return viewController
                }
            }
            viewController = TerminalViewController (host: host, interactive: interactive)
            return viewController
        case .rehost(rehost: let terminalView):
            viewController = TerminalViewController(terminalView: terminalView, interactive: interactive)
            return viewController
        }
    }
  
    func updateUIViewController(_ uiViewController: TerminalViewController, context: UIViewControllerRepresentableContext<SwiftUITerminal>) {
    }
}

