//
//  TmuxSessionGone.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 2/15/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct GenericConnectionIssue: View, ConnectionMessage {
    init(host: Host, message: String, ok: @escaping () -> ()) {
        self.ok = ok
        self.host = host
        self.error = message
    }
    
    @State var host: Host
    @State var error: String
    @State var ok: () -> () = { }
    
    var body: some View {
        VStack (alignment: .center){
            HStack (alignment: .center){
                Image (systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 30)
                    .padding (10)
                Text ("\(host.alias)")
                    .font(.title)
                Spacer ()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            //.background(.yellow)
            VStack (alignment: .center){
                Text (error)
                    .padding ([.bottom])
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

struct TmuxSessionGone_Previews: PreviewProvider {
    struct WrapperView: View {
        var host = Host ()
        
        var body: some View {
            HostConnectionError(host: host, error: "Test")
        }
    }
    static var previews: some View {
        WrapperView()
    }
}
