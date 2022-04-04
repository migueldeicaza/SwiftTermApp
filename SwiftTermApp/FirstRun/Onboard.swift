//
//  FirstRunWelcome.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/4/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct OnboardView: View {
    let last = 4
    @State var selection = 1
    @State var host = ""
    @State var port = ""
    
    var body: some View {
        VStack {
            TabView (selection: $selection) {
                OnboardWelcome (showOnboarding: .constant (true))
                Text ("Third")
                Text ("Fourth")
            }
            HStack {
                Spacer()
                Button {
                    withAnimation {
                        if selection == 0 {
                            selection += 1
                        }
                    }
                } label: {
                    HStack {
                        Text ("Continue")
                            .fontWeight(.semibold)
                            .font(.title)
                        if selection == last {
                            Image(systemName: "checkmark.circle")
                                .font(.largeTitle)
                        } else {
                            Image(systemName: "chevron.right.circle")
                                .font(.largeTitle)
                        }
                    }.padding()
                        .foregroundColor(.white)
                        .background(Color.primary)
                        .cornerRadius(20)

                }
            }
            .padding()
            .foregroundColor(.primary)
        }
    }
}

struct FirstRunWelcome_Previews: PreviewProvider {
    static var previews: some View {
        OnboardView()
    }
}
