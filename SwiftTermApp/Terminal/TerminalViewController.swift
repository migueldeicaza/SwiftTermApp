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
    var host: Host
    
    // This constructor is used to launch a new instance, and will trigger the SSH workflow
    init (host: Host)
    {
        self.host = host
        DataStore.shared.used (host: host)
        super.init(nibName: nil, bundle: nil)
    }

    // This consturctor is used to create a fresh TerminalViewController from an existing TerminalView
    init (terminalView: SshTerminalView)
    {
        self.terminalView = terminalView
        self.host = terminalView.host
        DataStore.shared.used (host: host)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeFrame (keyboardDelta: CGFloat) -> CGRect
    {
        print ("Making frame with \(keyboardDelta)")
        return CGRect (
            x: view.safeAreaInsets.left,
            y: view.safeAreaInsets.top,
            width: view.frame.width - view.safeAreaInsets.left - view.safeAreaInsets.right,
            height: view.frame.height - view.safeAreaInsets.bottom - view.safeAreaInsets.top - keyboardDelta)
    }
    
    func addKeyboardMonitor ()
    {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIWindow.keyboardWillHideNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardNotification(_:)),
            name: UIWindow.keyboardWillChangeFrameNotification,
            object: nil)
    }
    
    func removeKeyboardMonitor ()
    {
        NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillChangeFrameNotification, object: nil)
    }
    
    var can: Bool = true
    override var canBecomeFirstResponder: Bool {
        get {
            super.canBecomeFirstResponder && can
        }
    }

    @objc
    func keyboardNotification(_ notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            //let endFrameY = endFrame?.origin.y ?? 0
            let duration:TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
            let animationCurve:UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
//            if endFrameY >= UIScreen.main.bounds.size.height {
//                self.keyboardHeightLayoutConstraint?.constant = 0.0
//            } else {
//                self.keyboardHeightLayoutConstraint?.constant = endFrame?.size.height ?? 0.0
//            }
            
            let relative = view.convert(endFrame ?? CGRect.zero, from: view.window)
            
            let inter = relative.intersection(terminalView!.frame)
            if inter.height > 0 {
                view.frame = makeFrame(keyboardDelta: inter.height)
            }
            
            UIView.animate(withDuration: duration,
                                       delay: TimeInterval(0),
                                       options: animationCurve,
                                       animations: {

                                        self.view.layoutIfNeeded() },
                                       completion: nil)
        }
    }
        
    var keyboardDelta: CGFloat = 0
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        
    }
    
    @objc private func keyboardWillHide(_ notification: NSNotification) {
        //let key = UIResponder.keyboardFrameBeginUserInfoKey
        keyboardDelta = 0
        view.frame = makeFrame(keyboardDelta: 0)
    }
    
    func startConnection() -> SshTerminalView? {
        do {
            let tv = try SshTerminalView(frame: makeFrame (keyboardDelta: 0), host: host)
            tv.feed(text: "Welcome to SwiftTerm\n\n")
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
        addKeyboardMonitor()
        if terminalView == nil {
            terminalView = startConnection()
        }
        guard let t = terminalView else {
            return
        }
        // if it succeeded
        self.terminalView = t
        t.frame = view.frame
        t.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.autoresizesSubviews = true
        view.addSubview(t)
    
        t.becomeFirstResponder()
        Connections.track(connection: t)
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
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        removeKeyboardMonitor()
        
        super.viewWillDisappear(animated)
    }
}

typealias Controller = TerminalViewController

//
// This is the wrapper to use the TerminalViewController in Swift
//
final class SwiftUITerminal: NSObject, UIViewControllerRepresentable, UIDocumentPickerDelegate {
    
    typealias UIViewControllerType = TerminalViewController
    enum Kind {
        case host (host: Host, createNew: Bool)
        case rehost (rehost: SshTerminalView)
    }
    
    var kind: Kind

    init (host: Host, createNew: Bool)
    {
        kind = .host(host: host, createNew: createNew)
    }
    
    init (existing: SshTerminalView)
    {
        kind = .rehost(rehost: existing)
    }
    
    var viewController: TerminalViewController!

    func makeUIViewController(context: UIViewControllerRepresentableContext<SwiftUITerminal>) -> TerminalViewController {
        
        switch kind {
        case .host(host: let host, createNew: let createNew):
            if !createNew {
                if let v = Connections.lookupActive(host: host) {
                    return TerminalViewController(terminalView: v)
                }
            }
            return TerminalViewController (host: host)
        case .rehost(rehost: let terminalView):
            return TerminalViewController(terminalView: terminalView)
        }
    }
    
    func updateUIViewController(_ uiViewController: TerminalViewController, context: UIViewControllerRepresentableContext<SwiftUITerminal>) {
        
    }
}
