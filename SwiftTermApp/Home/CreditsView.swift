//
//  CreditsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/17/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section ("LazyView") {
                Text ("Chris Eidhof")
            }
            Section ("libssh2") {
                Text ("libssh2 license")
            }
            Section ("OpenSSL") {
                Text ("OpenSSL license")
            }
            Section ("SwCrypt") {
                Text ("SwiftSH License")
            }
            Section ("SwiftSH") {
                Text ("SwiftSH License")
            }
            Section ("SwiftTerm") {
                Text ("SwiftTerm License")
            }
        }.listStyle(.sidebar)
    }
}

struct CreditsView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsView()
    }
}
