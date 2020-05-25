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

class TerminalViewController: UIViewController {
    var tv: TerminalView?
    var host: Host
    
    init (host: Host)
    {
        self.host = host
        DataStore.shared.used (host: host)
        super.init(nibName: nil, bundle: nil)
        Connections.add(connection: self)
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
    
    func setupKeyboardMonitor ()
    {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIWindow.keyboardWillShowNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIWindow.keyboardWillHideNotification,
            object: nil)
    }
    
    var keyboardDelta: CGFloat = 0
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        let key = UIResponder.keyboardFrameBeginUserInfoKey
        guard let frameValue = notification.userInfo?[key] as? NSValue else {
            return
        }
        let frame = frameValue.cgRectValue
        keyboardDelta = frame.height
        tv?.frame = makeFrame(keyboardDelta: frame.height)
    }
    
    @objc private func keyboardWillHide(_ notification: NSNotification) {
        //let key = UIResponder.keyboardFrameBeginUserInfoKey
        keyboardDelta = 0
        tv?.frame = makeFrame(keyboardDelta: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        setupKeyboardMonitor()
        do {
            tv = try SshTerminalView(frame: makeFrame (keyboardDelta: 0), host: host)
        } catch MyError.noValidKey(let msg) {
            terminalViewCreationError (msg)
        } catch {
            terminalViewCreationError ("general")
        }
        if let t = tv {
            view.addSubview(t)
        
            t.becomeFirstResponder()
            t.feed(text: "Welcome to SwiftTerm\n\n")
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
    
    var screenshot: UIImage = UIImage (contentsOfFile: "/tmp/shot.png") ?? UIImage.init(systemName: "desktopcomputer")!
    
    override func viewWillDisappear(_ animated: Bool) {
        //screenshot = tv!.image ()

        let renderer = UIGraphicsImageRenderer(size: tv!.bounds.size)
        screenshot = renderer.image { ctx in
            tv!.layer.render(in: ctx.cgContext)
            //tv!.drawHierarchy(in: tv!.bounds, afterScreenUpdates: true)
        }
        if let data = screenshot.pngData() {
            try? data.write(to: URL (fileURLWithPath: "/tmp/shot.png"))
        }
        super.viewWillDisappear(animated)
    }
}

typealias Controller = TerminalViewController

final class SwiftUITerminal: NSObject, UIViewControllerRepresentable, UIDocumentPickerDelegate {
    
    typealias UIViewControllerType = TerminalViewController
    var host: Host
    var createNew: Bool
    
    init (host: Host, createNew: Bool)
    {
        self.host = host
        self.createNew = createNew
    }
    
    var viewController: TerminalViewController!

    func makeUIViewController(context: UIViewControllerRepresentableContext<SwiftUITerminal>) -> TerminalViewController {
        if !createNew {
            if let v = Connections.lookupActive(host: host) {
               return v
            }
        }
        return TerminalViewController (host: host)
    }
    
    func updateUIViewController(_ uiViewController: TerminalViewController, context: UIViewControllerRepresentableContext<SwiftUITerminal>) {
        print ("UpdateUIViewController")
    }
}
