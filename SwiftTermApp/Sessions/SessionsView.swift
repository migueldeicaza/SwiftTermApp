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

struct SessionDetailsView: View {
    var terminalView: SshTerminalView
    
    var body: some View {
        ZStack {
//            Rectangle ()
//                .fill(Color.gray.opacity(0.6))
                
            HStack {
                getImage(for: terminalView.host)
                    .colorInvert()
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text (terminalView.host.alias)
                            .bold()
                            .foregroundColor(Color.white)
                            
                        Spacer ()
                    }
                    Text (terminalView.host.summary())
                        //.blendMode(.colorBurn)
                        .brightness(0.8)
                        .font(.footnote)
                }
                Button (action: {
                    Connections.remove (self.terminalView)
                }) {
                    Image (systemName: "xmark.circle.fill")
                        .foregroundColor(Color.black)
                        .brightness(0.6)
                        .font(.system(size: 30))
                }
            }
        }
    }
}
/// Displays a mini-version of the terminal in session mode
///
/// This resizes the terminal
struct SessionView: View {
    @Environment(\.colorScheme) var colorScheme
    var terminalView: SshTerminalView
    var immediateController: SwiftUITerminal
    
    init (terminalView: SshTerminalView)
    {
        self.terminalView = terminalView
        self.immediateController = SwiftUITerminal(host: nil, existing: terminalView, createNew: false, interactive: false)
    }
    
    var body: some View {
        NavigationLink (destination:
                            ConfigurableUITerminal (host: nil, terminalView: terminalView, createNew: false, interactive: false)
                .navigationTitle (Text (terminalView.host.alias))
                .navigationBarTitleDisplayMode(.inline)

                .onDisappear { self.immediateController.rehost () })
        {
            VStack (spacing: 0){
                
                ZStack {
                    immediateController
                        .frame(minWidth: 300, minHeight: 240, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                        //.frame(width: previewWidth(), height: 240, alignment: .center)
                    Rectangle ()
                        .fill(Color.black.opacity(0.01))
                }
                SessionDetailsView (terminalView: terminalView)
            }
            .padding (10)
                //.background(Color (terminalView.nativeBackgroundColor.cgColor))
            // .background(Color.black)
            .background(colorScheme == .dark ? Color (.systemGray4) : .black)
            .mask(RoundedRectangle(cornerRadius: 10))
            .padding (8)
            .padding ([.leading, .trailing], 8)
        }.buttonStyle(PlainButtonStyle())
    }
}

///
/// Displays all the live sessions in a grid
///
struct SessionsView: View {
    @ObservedObject var connections = Connections.shared
    // Just to help me exercise the preview
    var repeatCount: Int = 1
    
    var body: some View {
        ScrollView {
            LazyVGrid (columns: [ GridItem(.adaptive(minimum: 340, maximum: 1000)) ]){
            if connections.connections.count > 0 {
//                ForEach (connections.connections.indices) { idx in
//                    ScreenOf (terminalView: self.connections.connections [idx])
//                }
                
                // The repeat count here is just to exercise the preview, no really other
                // reason
                //ForEach (0..<repeatCount) { x in
                    ForEach (connections.connections, id: \.id) { terminalView in
                        SessionView (terminalView: terminalView)
                    }

                //}
            } else {
                Text ("No active sessions")
            }
            }
            Spacer ()
        }.navigationTitle(Text("Sessions"))
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var v = SwiftUITerminal(host: DataStore.shared.hosts [0], existing: nil, createNew: true, interactive: true)
    static var previews: some View {
        Group {
            HStack {
                // This merely triggers the creation of SwiftUITerminal, that register the connection
                // necessary to show the SessionsView live
                v.frame (width: 0, height: 0, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                SessionsView(repeatCount: 5)
            }
            SessionsView (repeatCount: 5)
                .previewLayout(PreviewLayout.fixed(width:375,height:568))
            SessionsView (repeatCount: 5)
                .previewLayout(PreviewLayout.fixed(width:568,height:375))

        }
    }
}
