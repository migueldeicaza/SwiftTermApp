//
//  InputKeyboard.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/28/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct KbdButton: View {
    var text: String
    var sequence: [UInt8]
    
    var body: some View {
        Text (text)
            .frame(minWidth: 30, minHeight: 30)
            .lineLimit(1)
            .font (.system (size: 16))
            .foregroundColor(.primary)
            .padding(3)
            .background (Color (UIColor.systemBackground))
            .cornerRadius(3)
            .shadow(color: .gray, radius: 1, x: 0, y: 1)
            
    }
}

struct KbdLargeButton: View {
    var text: String
    var sequence: [UInt8]
    
    var body: some View {
        Text (text)
            .frame(minWidth: 40, minHeight: 30)
            .font (.system (size: 12))
            .foregroundColor(.primary)
            .padding(3)
            .background (Color (UIColor.tertiarySystemBackground))
            .cornerRadius(3)
            .shadow(color: .gray, radius: 1, x: 0, y: 1)
            
    }
}

struct KbdImage: View {
    var image: String
    var sequence: [UInt8]
    
    var body: some View {
        Image (systemName: image)
            .frame(minWidth: 40, minHeight: 30)
            .font (.system (size: 16))
            .foregroundColor(.primary)
            .padding(3)
            .background (Color (UIColor.tertiarySystemBackground))
            .cornerRadius(3)
            .shadow(color: .gray, radius: 1, x: 0, y: 1)
            
    }
}

struct KbdControls: View {
    let spec = [
        GridItem(.flexible(minimum: 40, maximum: 40)),
        GridItem(.flexible(minimum: 40, maximum: 40)),
        GridItem(.flexible(minimum: 40, maximum: 40))
    ]
    
    var body: some View {
        VStack {
            LazyVGrid (columns: spec) {
                KbdLargeButton (text: "Ins", sequence: [])
                KbdLargeButton (text: "Home", sequence: [])
                KbdLargeButton (text: "Page\nUp", sequence: [])
                KbdImage  (image: "delete.forward", sequence: [])
                KbdLargeButton (text: "End", sequence: [])
                KbdLargeButton (text: "Page\nDown", sequence: [])
            }
        }
    }
}

struct KbdAssortedKeys: View {
    let spec = [
        GridItem(.flexible(minimum: 30, maximum: 30)),
        GridItem(.flexible(minimum: 30, maximum: 30)),
        GridItem(.flexible(minimum: 30, maximum: 30)),
        GridItem(.flexible(minimum: 30, maximum: 30)),
        GridItem(.flexible(minimum: 30, maximum: 30)),
        GridItem(.flexible(minimum: 30, maximum: 30)),
    ]
    let keys: [(String, [UInt8])] = [
        ("{", []),
        ("}", []),
        ("(", []),
        (")", []),
        ("[", []),
        ("]", []),

        // Already on the top entry ~ | / -
        ("~" , []),
        ("?" , []),
        ("\\", []),
        (":" , []),
        (";" , []),
        ("\"", []),
        ("'" , []),
        ("+", []),
        ("-", []),
        ("*", []),
        ]
    
    var body: some View {
        VStack {
            LazyVGrid (columns: spec) {
                ForEach (keys.indices, id: \.self) { idx in
                    KbdButton(text: keys[idx].0, sequence: keys[idx].1)
                }
            }
        }
    }
}

struct InputKeyboard: View {
    let columns = [
        GridItem(.adaptive(minimum: 30))
    ]
    
    var body: some View {
        VStack {
            LazyVGrid (columns: columns){
                KbdButton (text: "F1", sequence: [])
                KbdButton (text: "F2", sequence: [])
                KbdButton (text: "F3", sequence: [])
                KbdButton (text: "F4", sequence: [])
                KbdButton (text: "F5", sequence: [])
                KbdButton (text: "F6", sequence: [])
                KbdButton (text: "F7", sequence: [])
                KbdButton (text: "F8", sequence: [])
                KbdButton (text: "F9", sequence: [])
                KbdButton (text: "F10", sequence: [])

            }
            HStack (alignment: .top) {
                KbdAssortedKeys ()
                KbdControls ()
            }
        }
    }
}

struct InputKeyboard_Previews: PreviewProvider {
    static var previews: some View {
        InputKeyboard()
    }
}
