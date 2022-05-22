//
//  CUserSnippet.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/21/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

extension CUserSnippet: UserSnippet {
    var title: String {
        get { sTitle ?? "" }
        set { sTitle = newValue }
    }
    
    var command: String {
        get { sCommand ?? "" }
        set { sCommand = newValue }
    }
    
    var platforms: [String] {
        get {
            guard let _s = sPlatforms else {
                return []
            }
            return _s.split(separator: ",").map { String ($0) }
        }
        set {
            sPlatforms = newValue.joined(separator: ",")
        }
    }
    
    public var id: UUID {
        get {
            if sId == nil {
                sId = UUID ()
            }
            return sId!
        }
        set { sId = newValue }
    }
    
    func toMemoryUserSnippet() -> MemoryUserSnippet {
        MemoryUserSnippet (title: title, command: command, platforms: platforms)
    }
}
