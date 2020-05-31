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

public class AppTerminalView: TerminalView {
    var id = UUID ()
    
    public override init (frame: CGRect) {
        super.init (frame: frame)
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
    
    func setFont (name: String, size: CGFloat)
    {
        if let uifont = UIFont (name: name, size: size) {
            // Need to change this so I can set the font directly
            //options = TerminalView.Options (font: TerminalView.Options.Font (font: uifont))
        }
    }
}
