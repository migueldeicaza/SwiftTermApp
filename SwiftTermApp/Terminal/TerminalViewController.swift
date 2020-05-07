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
    var tv: TerminalView!
    var host: Host
    
    init (host: Host)
    {
        self.host = host
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeFrame (keyboardDelta: CGFloat) -> CGRect
    {
        CGRect (x: view.safeAreaInsets.left,
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
        tv.frame = makeFrame(keyboardDelta: frame.height)
    }
    
    @objc private func keyboardWillHide(_ notification: NSNotification) {
        //let key = UIResponder.keyboardFrameBeginUserInfoKey
        keyboardDelta = 0
        tv.frame = makeFrame(keyboardDelta: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        setupKeyboardMonitor()
        tv = try? SshTerminalView(frame: makeFrame (keyboardDelta: 0), host: host)
        view.addSubview(tv)
        
        tv.becomeFirstResponder()
        tv.feed(text: "Welcome to SwiftTerm\n\n")
    }
    
    override func viewWillLayoutSubviews() {
        tv.frame = makeFrame (keyboardDelta: keyboardDelta)
    }
}


final class SwiftUITerminal: NSObject, UIViewControllerRepresentable, UIDocumentPickerDelegate {
    typealias UIViewControllerType = TerminalViewController
    var host: Host
    init (host: Host)
    {
        self.host = host
    }
    
    var viewController: TerminalViewController!

    func makeUIViewController(context: UIViewControllerRepresentableContext<SwiftUITerminal>) -> TerminalViewController {
        viewController = TerminalViewController (host: host)
        DataStore.shared.used (host: host)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: TerminalViewController, context: UIViewControllerRepresentableContext<SwiftUITerminal>) {
    }
}
