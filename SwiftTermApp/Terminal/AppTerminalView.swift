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

public class AppTerminalView: TerminalView {
    var id = UUID ()
    var sizeChange: AnyCancellable?
    var fontChange: AnyCancellable?
    var themeChange: AnyCancellable?
    
    public override init (frame: CGRect) {
        super.init (frame: frame)
        sizeChange = settings.$fontSize.sink { _ in self.updateFont () }
        fontChange = settings.$fontName.sink { _ in self.updateFont () }
        themeChange = settings.$themeName.sink { _ in self.applyTheme(theme: settings.getTheme()) }
    }

    func updateFont ()
    {
        if let uifont = UIFont (name: settings.fontName, size: settings.fontSize) {
            font = uifont
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func applyTheme (theme: ThemeColor)
    {
        installColors(theme.ansi)
        let t = getTerminal()
        t.foregroundColor = theme.foreground
        t.backgroundColor = theme.background
        
        // TODO: selection and caret colors
    }
}
