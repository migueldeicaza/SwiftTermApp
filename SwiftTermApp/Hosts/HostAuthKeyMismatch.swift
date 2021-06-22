//
//  HostAuthKeyMismatch.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/21/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct HostAuthKeyMismatch: View {
    @State var alias: String
    @State var hostString: String
    @State var fingerprint: String

    var body: some View {
        VStack (alignment: .leading){
            HStack (alignment: .center){
                Image (systemName: "exclamationmark.triangle")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 30)
                    .padding (10)
                VStack (alignment: .leading){
                    Text ("Warning host: \(alias)")
                        .font(.title)
                    Text ("The Remote Host Identification has changed")
                }
                Spacer ()
            }
            .padding()
            .background(.yellow)
            VStack {
                Text ("**It is possible that someone is doing something nasty**.\n\nSomeone could be eavesdropping on you right now (man-in-the-middle attack).\n\nIt is also possible that the host key has just been changed. The fingerprint for the RSA key sent by the remote host is `\(fingerprint)`.  Contact your system administrator to verify.\n\nIf this is expected, you can remove the existing known key from the Known Hosts settings.")
                    .padding ([.bottom])
                
                Button ("Go Back", role: .cancel) { }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .controlProminence(.increased)
                    .tint(Color.red)
            }
            .padding()
        }
    }}

struct HostAuthKeyMismatch_Previews: PreviewProvider {
    static var previews: some View {
        HostAuthKeyMismatch(alias: "mac", hostString: "localhost:20", fingerprint: "ECDSA SHA256:AAAAB3NzaC1yc2EAAAADAQABAAABgQDCOFP4DoqHmagF")
    }
}
