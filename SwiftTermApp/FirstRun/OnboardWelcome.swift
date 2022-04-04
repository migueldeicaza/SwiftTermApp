//
//  Welcome.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/4/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct OnboardWelcome: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        VStack (alignment: .leading){
            HStack (alignment: .top){
                Image (systemName: "terminal.fill")
                    .font (.system(size: 72))
                VStack (alignment: .leading){
                    Text ("Welcome to SwiftTerm")
                        .fontWeight(.semibold)
                        .font (.title)
                    Text ("A terminal emulator and SSH client for iOS")
                        .font (.title2)
                }
            }
            VStack {
                HStack (alignment: .top){
                    Image (systemName: "desktopcomputer")
                        .font(.system(size: 30))
                        .foregroundColor(Color.accentColor)
                        .frame(minWidth: 50)
                    Text ("To get started, create a new host definition that includes the address of the machine you want to connect to, and the username to login as.")
                        .minimumScaleFactor(0.7)
                    Spacer ()
                }.padding ()

                HStack (alignment: .top){
                    Image (systemName: "key")
                        .font(.system(size: 30))
                        .foregroundColor(Color.accentColor)
                        .frame(minWidth: 50)
                    Text ("You can then import existing SSH keys, or create new ones.")
                        .minimumScaleFactor(0.7)
                    Spacer ()
                }.padding()
                Button ("Dismiss") {
                    showOnboarding = false
                }
            }
        }
        .padding ()
    }
}

struct Welcome_Previews: PreviewProvider {
    static var previews: some View {
        OnboardWelcome (showOnboarding: .constant(true))
    }
}
