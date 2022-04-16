//
//  HostAuthUnknown.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/21/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct HostAuthUnknown: View {
    @State var alias: String
    @State var hostString: String
    @State var fingerprint: String
    var cancelCallback: () -> () = {  }
    var okCallback: () -> () = {  }
    
    var body: some View {
        VStack (alignment: .leading){
            HStack (alignment: .center){
                Image (systemName: "info.circle")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .foregroundColor(Color.accentColor)
                    .frame(width: 30)
                    .padding (10)
                Text ("Host: \(alias)")
                    .font(.title)
                Spacer ()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            //.background(.yellow)
            VStack {
                Text ("The authenticity of host '`\(hostString)`' can not be established.\n\nIf this is the first time you connect to this host, you can check that the fingertprint for the host matches the fingerprint you recognize and then proceed. Otherwise, select cancel.\n\nFingerprint:\n\n`\(fingerprint)`\n\nDo you want to continue connecting?")
                    .padding ([.bottom])
                HStack (alignment: .center, spacing: 20) {
                    Button ("Cancel", role: .cancel) { cancelCallback () }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(Color.red)

                    Button ("Yes", role: .none) { okCallback ()}
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding()
        }
    }
}

struct HostAuthUnknown_Previews: PreviewProvider {
    static var previews: some View {
        HostAuthUnknown(alias: "mac", hostString: "localhost:22", fingerprint: "ECDSA SHA256:AAAAB3NzaC1yc2EAAAADAQABAAABgQDCOFP4DoqHmagF")
    }
}
