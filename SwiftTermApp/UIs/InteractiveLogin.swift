//
//  InteractiveLogin.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/10/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct InteractiveLogin: View {
    @State var host: Host?
    @State var username: String = ""
    
    var body: some View {
        VStack {
            Text ("Connecting")
                .padding ()
            Text (host?.hostname ?? "No Host")
            TextField ("Username", text: $username)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(Color (#colorLiteral(red: 0.921431005, green: 0.9214526415, blue: 0.9214410186, alpha: 1)))

                .padding()
                .frame(maxWidth: 240)
            HStack {
                Button (action: {}) { Text ("Connect") }
            }
            Spacer ()
        }
    }
}

struct InteractivePassword: View {
    @State var host: Host?
    @State var username: String = ""
    
    var body: some View {
        VStack {
            Text ("Password")
                .padding ()
            Text (host?.hostname ?? "No Host")
            TextField ("Password", text: $username)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(Color (#colorLiteral(red: 0.921431005, green: 0.9214526415, blue: 0.9214410186, alpha: 1)))

                .padding()
                .frame(maxWidth: 240)
            HStack {
                Button (action: {}) { Text ("Connect") }
            }
            Spacer ()
        }
    }
}

struct InteractiveLogin_Previews: PreviewProvider {
    static var previews: some View {
        Text ("Test")
            .sheet(isPresented: .constant(true)) {
                HStack {
                    InteractiveLogin ()
                    InteractivePassword()
                }
        }
    }
}
