//
//  DataExtensions.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 2/7/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

extension Data {
    public func getDump(indent: String = "") -> String {
        let res = self.withUnsafeBytes { data -> String in
            var hexstr = String()
            var txt = String ()
            var n = 0
            for i in data.bindMemory(to: UInt8.self) {
                if (n % 16) == 0 {
                    hexstr += " \(txt)\n" + String (format: "%04x: ", n)
                    txt = ""
                }
                n += 1
                hexstr += String(format: "%02X ", i)
                txt += (i > 32 && i < 127 ? String (Unicode.Scalar (i)) : ".")
            }
            hexstr += " \(txt)"
            return hexstr.replacingOccurrences(of: "\n", with: "\n\(indent)")
        }
        return res
    }
    
    public func dump() {
        print (getDump ())
    }
}
