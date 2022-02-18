//
//  AppTerminalView.swift - implements our base class derived from TerminalView with
//  any app-specific enhancements that should be shared across front-ends (Ssh and Local
//  when this works in Catalyst)
//
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/30/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftTerm
import UIKit
import Combine

/**
 * AppTerminalView is the subclass of TerminalView that provides the integration
 * into SwiftTermApp, it monitors the global `settings` for changes and
 * applies that to the terminal and also handles the Metal changes for the
 * Live backgrounds.
 *
 * Additionally, it has the "pinch" handler for changing the font size.
 *
 * The `SshTerminalView` is a subclass that adds other capabilities
 */
public class AppTerminalView: TerminalView {
    var id = UUID ()
    let host: Host
    var disableFirstResponderDuringViewRehosting: Bool = false
    /// This variable is turned on when the user has manually changed the size by pinching, and it used
    /// to ignore global changes after the user triggered the pinch change.
    var userOverrideSize = false
    
    // These are the handlers used to track changes on the global `settings` variables
    var sizeChange: AnyCancellable?
    var fontChange: AnyCancellable?
    var themeChange: AnyCancellable?
    var backgroundChange: AnyCancellable?
    var hostChange: AnyCancellable?
    
    /// If set, it means that we are using Metal for our background
    var metalHost: MetalHost?
    
    var keyboardTapRecognizer: UITapGestureRecognizer!
    
    /// 
    var metalLayer: CAMetalLayer?
    
    /// If set, it will monitor for theme changes in `settings` and apply those, otherwise it leaves them as-is (so
    var useSharedTheme: Bool { host.style == "" }
    var useDefaultBackground: Bool { host.background == "default" }
    
    init (frame: CGRect, host: Host) throws {
        self.host = host
        super.init (frame: frame)
        
        // Changes that take place by global settings
        sizeChange = settings.$fontSize.sink { newSize in
            if !self.userOverrideSize {
                self.updateFont (newSize: newSize)
            }
        }
        fontChange = settings.$fontName.sink { _ in self.updateFont (newSize: settings.fontSize) }
        themeChange = settings.$themeName.sink { _ in
            if self.useSharedTheme {
                self.applyTheme(theme: settings.getTheme())
            }
        }
        backgroundChange = settings.$backgroundStyle.sink { _ in
            self.updateBackground (background: self.useDefaultBackground ? settings.backgroundStyle : host.background)
        }
        
        /// Changes that can happen on the host itself
        hostChange = DataStore.shared.runtimeVisibleChanges.sink { host in
            if host.id == self.host.id {
                self.updateBackground (background: self.useDefaultBackground ? settings.backgroundStyle : host.background)
                
                if host.style == "" {
                    self.applyTheme(theme: settings.getTheme())
                } else {
                    self.applyTheme(theme: settings.getTheme (themeName: host.style))
                }

            }
        }

        addGestureRecognizer(UIPinchGestureRecognizer (target: self, action: #selector(pinchHandler)))
        keyboardTapRecognizer = UITapGestureRecognizer (target: self, action: #selector (activate))
    }

    override public func becomeFirstResponder() -> Bool {
        if super.becomeFirstResponder() {
            return true
        }
        return false
    }
    
    override public func resignFirstResponder() -> Bool {
        if disableFirstResponderDuringViewRehosting {
            return true
        }
        
        addGestureRecognizer(keyboardTapRecognizer)
        if super.resignFirstResponder() {
            return true
        }
        return false
    }
    
    @objc
    func activate ()
    {
        if becomeFirstResponder() {
            removeGestureRecognizer(keyboardTapRecognizer)
        }
    }
    
    override public func didMoveToWindow() {
        if let mh = metalHost {
            mh.didMoveToWindow(view: self)
        }
    }
    
    func updateBackground (background: String)
    {
        // solid
        if background == "" {
            if let m = metalHost {
                m.stopRunning()
                metalLayer?.removeFromSuperlayer()
                metalLayer = nil
                metalHost = nil
            }
        } else {
            if metalLayer == nil {
                metalLayer = CAMetalLayer ()
                metalLayer!.frame = frame
                //metalLayer?.opacity = 0.4
                
                // If we are currently attached to a ViewController (ie, we are up and running, as opposed to bootstarpping)
                // we should insert the layer directioly.
                if let mySuper = superview {
                    mySuper.layer.insertSublayer(metalLayer!, at: 0)
                }
            }

            if let m = metalHost {
                if m.fragmentName != background {
                    m.stopRunning()
                    metalHost = MetalHost (target: metalLayer!, fragmentName: background)
                    metalHost!.startRunning()
                }
            } else {
                metalHost = MetalHost (target: metalLayer!, fragmentName: background)
                metalHost!.startRunning()
            }
            backgroundColor = UIColor.clear
        }
    }
    
    public override var bounds: CGRect {
        get {
            return super.bounds
        }
        set {
            super.bounds = newValue
            
            if let ml = metalLayer {
                ml.frame = CGRect (origin: CGPoint.zero, size: newValue.size)
            }
        }
    }
    
    public override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            
            if let ml = metalLayer {
                ml.frame = CGRect (origin: CGPoint.zero, size: newValue.size)
            }
        }
    }
    
    func updateFont (newSize: CGFloat)
    {
        if settings.fontName == "SF Mono" {
            font = UIFont.monospacedSystemFont(ofSize: newSize, weight: .regular)
        } else if let uifont = UIFont (name: settings.fontName, size: newSize) {
            font = uifont
        }
    }
    
    @objc
    func pinchHandler (_ gestureRecognizer: UIPinchGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            
            let new = font.pointSize * gestureRecognizer.scale
            gestureRecognizer.scale = 1.0
            
            if new < 5 || new > 72 {
                return
            }
            if let uifont = UIFont (name: settings.fontName, size: new) {
                userOverrideSize = true
                font = uifont
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeUIColor (_ color: SwiftTerm.Color) -> UIColor
    {
        UIColor (red: CGFloat (color.red) / 65535.0,
                 green: CGFloat (color.green) / 65535.0,
                 blue: CGFloat (color.blue) / 65535.0,
                 alpha: 1.0)
    }
    
    func applyTheme (theme: ThemeColor)
    {
        installColors(theme.ansi)
        let t = getTerminal()
        t.foregroundColor = theme.foreground
        t.backgroundColor = theme.background
        if metalHost != nil {
            nativeBackgroundColor = UIColor.clear
        }
        self.selectedTextBackgroundColor = makeUIColor (theme.selectionColor)
        self.caretColor = makeUIColor (theme.cursor)
        

        // TODO: selection and caret colors
    }
}
