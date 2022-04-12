//
//  TerminalButton.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/1/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct STButton: View {
    var text: String
    let icon: String
    @State var centered = true
    @Environment(\.colorScheme) var colorScheme
    var action: ()->Void

    var body: some View {
        Button (action: action) {
            HStack {
                if centered {
                    Spacer()
                }
                Image (systemName: icon)
                    .foregroundColor(colorScheme == .dark ? ButtonColors.darkHighColor : ButtonColors.highColor)
                    .font(Font.title.weight(.semibold))
                Text (self.text)
                    .foregroundColor(colorScheme == .dark ? ButtonColors.darkHighColor : ButtonColors.highColor)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding (10)
            .background(colorScheme == .dark ? ButtonColors.darkBackgroundColor : ButtonColors.backgroundColor)
            .cornerRadius(12)
            .foregroundColor(colorScheme == .dark ? ButtonColors.darkHighColor : ButtonColors.highColor)
            .padding([.horizontal])
        //.frame (maxWidth: 400)
        }
    }
}

struct STButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                STButton(text: "Hello", icon: "gear") {}
                STButton(text: "Centered=false", icon: "gear", centered: false) {}
            }
            .preferredColorScheme(.dark)
            .previewInterfaceOrientation(.portrait)
            VStack {
                STButton(text: "Hello", icon: "gear"){}
                STButton(text: "Centered=false", icon: "gear", centered: false) {}
            }
            .previewInterfaceOrientation(.portrait)
        }
    }
}
