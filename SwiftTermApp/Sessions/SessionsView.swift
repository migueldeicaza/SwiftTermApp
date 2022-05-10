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
    @Binding var count: Int
    var body: some View {
        ZStack {
//            Rectangle ()
//                .fill(Color.gray.opacity(0.6))
                
            HStack {
                getHostImage(forKind: terminalView.host.hostKind)
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
                    Connections.remove (terminal: self.terminalView)
                    count = Connections.shared.terminals.count
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
    @Binding var count: Int
    
    init (terminalView: SshTerminalView, count: Binding<Int>)
    {
        self.terminalView = terminalView
        self.immediateController = SwiftUITerminal(host: nil, existing: terminalView, createNew: false, interactive: false)
        self._count = count
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
                SessionDetailsView (terminalView: terminalView, count: $count)
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
    @State var count: Int
    
    init ()
    {
        count = Connections.shared.terminals.count
    }
    
    var body: some View {
        HStack {
            if count > 0 {
                ScrollView {
                    LazyVGrid (columns: [ GridItem(.adaptive(minimum: 340, maximum: 1000)) ]){
                        //                ForEach (connections.connections.indices) { idx in
                        //                    ScreenOf (terminalView: self.connections.connections [idx])
                        //                }
                        
                        ForEach (connections.terminals, id: \.id) { terminalView in
                            SessionView (terminalView: terminalView, count: $count)
                        }
                    }
                }
                .navigationTitle(Text("Sessions"))
            } else {
                NoSessionsView()
                    .navigationTitle(Text("Sessions"))
            }
        }.onAppear {
            // Need to get the count out at init and onAppear, rather than directly
            // referencing it, otherwise when we create the connection, the view
            // is recomputed causing the effect where it "pushes" the terminal, and
            // then pops back up to the session small preview

            count = Connections.shared.terminals.count
        }
    }
}

struct NoSessionsView: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack {
            Spacer ()
            HStack {
                //Spacer ()
                Image (systemName: "terminal.fill")
                    .font (.system (size: 72))
                VStack (alignment: .leading){
                    Text ("No active sessions")
                        .font (.title)
                    Text ("Active SSH sessions will appear here")
                }
                Spacer ()
            }
            if self.store.recentIndices().count > 0 {
                VStack (alignment: .leading){
                    Text ("Recent Connections")
                        .font (.title3)
                    if horizontalSizeClass == .compact {
                        RecentHostsView()
                    } else {
                        ScrollView {
                            VStack {
                                RecentHostsView (limit: 10)
                            }.padding()
                        }
                    }
                }.padding ([.top])
            }
            Spacer ()
            Spacer ()
            Spacer ()
        }.padding (horizontalSizeClass == .compact ? 0 : 80)
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var v = SwiftUITerminal(host: DataStore.shared.hosts [0], existing: nil, createNew: true, interactive: true)
    static var previews: some View {
        Group {
            NoSessionsView ()
            HStack {
                // This merely triggers the creation of SwiftUITerminal, that register the connection
                // necessary to show the SessionsView live
                v.frame (width: 0, height: 0, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                SessionsView()
            }
            SessionsView ()
                .previewLayout(PreviewLayout.fixed(width:375,height:568))
            SessionsView ()
                .previewLayout(PreviewLayout.fixed(width:568,height:375))

        }
    }
}
