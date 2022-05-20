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
        self._host = State (initialValue: host)
        self._error = State (initialValue: message)
        self._ok = State (initialValue: ok)
    }
    
    @State var host: Host
    @State var error: String
    @State var ok: () -> () = { }
    
    var body: some View {
        VStack (alignment: .center){
            HStack (alignment: .center){
                Image (systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
        var host: Host
        
        init () {
            host = CHost (context: DataController.preview.container.viewContext)
            host.alias = "dbserver"
            host.hostname = "dbserver.domain.com"
        }
        
        var body: some View {
            HostConnectionError(host: host, error: "Other end got unhappy")
        }
    }
    static var previews: some View {
        WrapperView()
    }
}
