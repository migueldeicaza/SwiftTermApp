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
                    Text ("Want to try something new?")
                        .fontWeight(.semibold)
                        .font (.title)
                    Text ("Coming soon...")
                        .font (.title2)
                }
            }
            VStack {
                HStack (alignment: .top){
                    Image (systemName: "paperplane")
                        .font(.system(size: 30))
                        .foregroundColor(Color.accentColor)
                        .frame(minWidth: 50)
                    Text ("In preparation for an iOS App Store launch, we’re giving this app a new name, new branding, and some new features.\n\nWe’d love to have discerning terminal enthusiasts such as yourself come along for the ride. ")
                        .minimumScaleFactor(0.7)
                    Spacer ()
                }.padding ()

                HStack (alignment: .top){
                    Image (systemName: "envelope")
                        .font(.system(size: 30))
                        .foregroundColor(Color.accentColor)
                        .frame(minWidth: 50)
                    Text ("If this sounds like you, please fill out [this short form](https://bit.ly/3I7luFH) to sign up for our new TestFlight program.")
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
