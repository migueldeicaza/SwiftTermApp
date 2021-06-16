//
//  QuickLauch.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/20/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct DelayedSwiftUITerminal: View {
    @Binding var destHost: Host?
    
    var body: some View {
        SwiftUITerminal(host: self.destHost!, existing: nil, createNew: true, interactive: true)
    }
}
struct QuickLaunch: View {
    @State var quickCommand: String = ""
    @State var destHost: Host?
    @State var activate: Bool = false
    
    func go () {
        guard quickCommand.count > 0 else { return }
        let sp1 = quickCommand.split (separator: ":")
        let sp2 = String (sp1 [0]).split (separator: "@")
        let user, host: String
        if sp2.count == 1 {
            host = String (sp2 [0])
            user = ""
        } else {
            user = String (sp2 [0])
            host = String (sp2 [1])
        }
        let port = sp1.count > 1 ? Int (String (sp1 [1])) ?? 22 : 22
        
        destHost = Host(alias: quickCommand,
                        hostname: host,
                    
                        lastUsed: Date())
        activate = true
    }
    
    var body: some View {
        NavigationLink(destination: DelayedSwiftUITerminal (destHost: $destHost), isActive: $activate)  {
            HStack {
                
                TextField("user@hostname:22", text: $quickCommand)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                Button(action: { self.go () }) {
                    Text ("Connect")
                }
            }
        }
        .isDetailLink(false)
        .allowsHitTesting(false)
        .onAppear() {
            self.destHost = nil
        }
    }
}

struct QuickLaunch_Previews: PreviewProvider {
    static var previews: some View {
        QuickLaunch()
    }
}
