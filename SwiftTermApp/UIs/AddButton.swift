//
//  AddButton.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/1/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct AddButton: View {
    let highColor = Color(#colorLiteral(red: 0.007762347814, green: 0.4766914248, blue: 0.9985215068, alpha: 1))
    let backgroundColor = Color(#colorLiteral(red: 0.9307063222, green: 0.945577085, blue: 0.9838711619, alpha: 1))
    var text: String
    
    var body: some View {
        HStack {
            Spacer()
            Image (systemName: "plus.circle")
                .foregroundColor(highColor)
                .font(Font.title.weight(.semibold))
            Text (self.text)
                .foregroundColor(highColor)
                .fontWeight(.bold)
            Spacer()
        }
        .padding ()
        .background(backgroundColor)
        .cornerRadius(10)
        .foregroundColor(highColor)
        .padding()
    }
}

