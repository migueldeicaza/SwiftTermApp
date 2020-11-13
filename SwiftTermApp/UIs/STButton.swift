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

    var body: some View {
        HStack {
            Spacer()
            Image (systemName: icon)
                .foregroundColor(ButtonColors.highColor)
                .font(Font.title.weight(.semibold))
            Text (self.text)
                .foregroundColor(ButtonColors.highColor)
                .fontWeight(.bold)
            Spacer()
        }
        .padding (10)
        .background(ButtonColors.backgroundColor)
        .cornerRadius(12)
        .foregroundColor(ButtonColors.highColor)
        .padding()
    }
}


struct STButton_Previews: PreviewProvider {
    static var previews: some View {
        STButton(text: "Hello", icon: "gear")
    }
}
