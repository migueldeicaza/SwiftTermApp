//
//  HostConnectionClosed.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/23/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct HostConnectionClosed: View {
    @State var host: Host
    @State var receivedEOF: Bool
    @State var ok: () -> () = { }
    
    var body: some View {
        VStack (alignment: .center){
            HStack (alignment: .center){
                
                Image (systemName: receivedEOF ? "info.circle" : "desktopcomputer.trianglebadge.exclamationmark")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40)
                    .padding (10)
                Text ("\(host.alias)")
                    .font(.title)
                Spacer ()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            //.background(.yellow)
            VStack (alignment: .center){
                Text ("Connection to `\(host.hostname):\(String (host.port))` \(receivedEOF ? " was closed" : " terminated")")
                    .padding ([.bottom])
                Spacer ()
                HStack (alignment: .center, spacing: 20) {
                    Button ("Ok") { ok () }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding()
            Spacer ()
        }
    }
}

struct HostConnectionClosed_Previews: PreviewProvider {
    static var previews: some View {
        WrapperView ()
    }
    
    struct WrapperView: View {
        var host = Host (alias: "dbserver", hostname: "dbserver-1.prod.com")
        
        var body: some View {
            HostConnectionClosed(host: host, receivedEOF: false)
        }
    }
}
