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
    
    /// If set, it will monitor for theme changes in `settings` and apply those, otherwise it leaves them as-is (so
    var useSharedTheme: Bool
    
    /// This variable is turned on when the user has manually changed the size by pinching, and it used
    /// to ignore global changes after the user triggered the pinch change.
    var userOverrideSize = false
    
    // These are the handlers used to track changes on the global `settings` variables
    var sizeChange: AnyCancellable?
    var fontChange: AnyCancellable?
    var themeChange: AnyCancellable?
    var backgroundChange: AnyCancellable?
    
    /// If set, it means that we are using Metal for our background
    var metalHost: MetalHost?
    
    /// 
    var metalLayer: CAMetalLayer?
    
    public init (frame: CGRect, useSharedTheme: Bool, useDefaultBackground: Bool) {
        self.useSharedTheme = useSharedTheme
        super.init (frame: frame)
        sizeChange = settings.$fontSize.sink { newSize in
            if !self.userOverrideSize {
                self.updateFont (newSize: newSize)
            }
        }
        fontChange = settings.$fontName.sink { _ in self.updateFont (newSize: settings.fontSize) }
        themeChange = settings.$themeName.sink { _ in
            if useSharedTheme {
                self.applyTheme(theme: settings.getTheme())
                
            }
        }
        if useDefaultBackground {
            backgroundChange = settings.$backgroundStyle.sink { _ in self.updateBackground (background: settings.backgroundStyle) }
        }
        
        addGestureRecognizer(UIPinchGestureRecognizer (target: self, action: #selector(pinchHandler)))
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
                metalLayer = nil
            }
        } else {
            if metalLayer == nil {
                metalLayer = CAMetalLayer ()
                //metalLayer?.opacity = 0.4
                metalHost = MetalHost (target: metalLayer!, fragmentName: background)
                backgroundColor = UIColor.clear
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
                ml.frame = bounds
            }
        }
    }
    
    func updateFont (newSize: CGFloat)
    {
        if let uifont = UIFont (name: settings.fontName, size: newSize) {
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
    
    func makeUIColor (_ color: Color) -> UIColor
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
        if metalLayer != nil {
            nativeBackgroundColor = UIColor.clear
        }
        self.selectedTextBackgroundColor = makeUIColor (theme.selectionColor)
        self.caretColor = makeUIColor (theme.cursor)
        
        // TODO: selection and caret colors
    }
}
