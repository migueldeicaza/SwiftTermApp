//
//  ColorLoader.swift
//  Loads colors from the XRDB format and distributed by the iTerm2colorschemes.com site
//
//  Created by Miguel de Icaza on 5/29/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftTerm

struct ThemeColor: Hashable, Equatable {
    var name: String
    var ansi: [Color]
    var background: Color
    var foreground: Color
    var cursor: Color
    var cursorText: Color
    var selectedText: Color
    var selectionColor: Color
    
    static func parseColor (_ txt: [Substring.Element]) -> Color?
    {
        func getHex (_ idx: Int) -> UInt16 {
            var n: UInt16 = 0
            let c = txt [idx].asciiValue ?? 0
            
            if c >= UInt8(ascii: "0") && c <= UInt8 (ascii: "9"){
                n = UInt16 (c - UInt8(ascii: "0"))
            } else if c >= UInt8(ascii: "a") && c <= UInt8 (ascii: "f") {
                n = UInt16 ((c - UInt8(ascii:"a") + 10))
            } else if c >= UInt8(ascii: "A") && c <= UInt8 (ascii: "F") {
                n = UInt16 ((c - UInt8(ascii:"A") + 10))
            }
            return n
        }
        guard txt.count == 7 else { return nil }
        guard txt [0] == "#" else { return nil }
        
        let r = getHex (1) << 4 | getHex (2)
        let g = getHex (3) << 4 | getHex (4)
        let b = getHex (5) << 4 | getHex (6)
        return Color (red: r*257, green: g*257, blue: b*257)
    }
    
    // Returns a ThemeColor from an Xrdb string (this should contain the whole file)
    // xrdb is one of the simpler formats supported on the iTerm2 web site with themes
    static func fromXrdb (title: String, xrdb: String) -> ThemeColor? {
        var ansi: [Int:Color] = [:]
        var background: Color?
        var foreground: Color?
        var cursor: Color?
        var cursorText: Color?
        var selectedText: Color?
        var selectionColor: Color?
        
        for l in xrdb.split (separator: "\n") {
            let elements = l.split (separator: " ")
            let color = parseColor (Array (elements [2]))
            switch elements [1]{
            case "Ansi_0_Color":
                ansi [0] = color
            case "Ansi_1_Color":
                ansi [1] = color
            case "Ansi_10_Color":
                ansi [10] = color
            case "Ansi_11_Color":
                ansi [11] = color
            case "Ansi_12_Color":
                ansi [12] = color
            case "Ansi_13_Color":
                ansi [13] = color
            case "Ansi_14_Color":
                ansi [14] = color
            case "Ansi_15_Color":
                ansi [15] = color
            case "Ansi_2_Color":
                ansi [2] = color
            case "Ansi_3_Color":
                ansi [3] = color
            case "Ansi_4_Color":
                ansi [4] = color
            case "Ansi_5_Color":
                ansi [5] = color
            case "Ansi_6_Color":
                ansi [6] = color
            case "Ansi_7_Color":
                ansi [7] = color
            case "Ansi_8_Color":
                ansi [8] = color
            case "Ansi_9_Color":
                ansi [9] = color
            case "Background_Color":
                background = color
            case "Cursor_Color":
                cursor = color
            case "Cursor_Text_Color":
                cursorText = color
            case "Foreground_Color":
                foreground = color
            case "Selected_Text_Color":
                selectedText = color
            case "Selection_Color":
                selectionColor = color
            default:
                break
            }
        }
        if ansi.count == 16 {
            if let bg = background, let fg = foreground, let ct = cursorText,
                let cu = cursor, let st = selectedText, let sc = selectionColor {
                
                return ThemeColor (name: title,
                                   ansi: [Color] (ansi.keys.sorted().map { v in ansi [v]! }),
                                   background: bg,
                                   foreground: fg,
                                   cursor: cu,
                                   cursorText: ct,
                                   selectedText: st,
                                   selectionColor: sc)
            }
            
        }
        return nil
    }
}
