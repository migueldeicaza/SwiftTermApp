//
//  SessionsView.swift
//  SwiftTermApp
//
// Displays live sessions.
//
//  Created by Miguel de Icaza on 4/28/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct SessionView: View {
    var name: String
    var summary: String
    var terminalView: SshTerminalView

    var body: some View {
        VStack {
        
            ZStack {
                SwiftUITerminal(existing: terminalView)
                    .frame(width: 320, height: 240, alignment: .center)
            }
            HStack {
                getImage(for: terminalView.host)
                    .colorInvert()
//                Image (systemName: "desktopcomputer")
//                    .font (.system(size: 28))
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text (name)
                            .bold()
                            .foregroundColor(Color.white)
                        Spacer ()
                    }
                    Text (summary)
                        .brightness(0.6)
                        .font(.footnote)
                }
                Button (action: { print ("Should Close Session")}) {
                    Image (systemName: "xmark.circle.fill")
                        .foregroundColor(Color.black)
                        .brightness(0.6)
                        .font(.system(size: 30))
                }
            }
        }.padding (10)
            .background(Color.black)
            .mask(RoundedRectangle(cornerRadius: 10))
            .padding ([.leading, .trailing], 16)
            .onTapGesture {
                print ("Should activate this session")
        }
    }
}
struct ScreenOf: View {
    var terminalView: SshTerminalView
    
    var body: some View {
        print ("running")
        return VStack {
            SessionView (name: terminalView.host.alias, summary: terminalView.host.summary(), terminalView: terminalView)
        }
    }
}

struct SessionsView: View {
    @ObservedObject var connections = Connections.shared

    var body: some View {
        ScrollView {
            if connections.connections.count > 0 {
                ForEach (connections.connections.indices) { idx in
                    ScreenOf (terminalView: self.connections.connections [idx])
                }
            } else {
                Text ("No active sessions")
            }
            Spacer ()
        }.navigationBarTitle(Text("Sessions"))
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}
