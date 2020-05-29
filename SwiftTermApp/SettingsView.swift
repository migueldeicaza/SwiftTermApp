//
//  SettingsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/28/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

var fontNames: [String] = ["Courier", "Courier New", "Menlo"]

enum BeepKind {
    case silent
    case beep
    case vibrate
}

class Settings: ObservableObject {
    @Published var keepOn: Bool = true
    @Published var fontIdx: Int = 0
    @Published var beepConfig: BeepKind = .vibrate
    
    init () {}
}

var settings = Settings()


struct AppearanceSelector: View {
    var body: some View {
        Text ("Theme selector")
    }
}

struct SettingsView: View {
    @State var fontIdx = 0
    @ObservedObject var gset = settings
    
    var body: some View {
        NavigationView {
            Form {
                NavigationLink("Appearance", destination: AppearanceSelector ())
                Picker(selection: $gset.fontIdx, label: Text ("Font")) {
                    ForEach (fontNames.indices) { idx in
                        Text (fontNames [idx])
                            .font(.custom(fontNames [idx], size: 17))
                            .tag (idx)
                    }
                }
                Toggle(isOn: $gset.keepOn) {
                    Text ("Keep Display On")
                }
                // Keyboard
                Picker (selection: $gset.beepConfig, label: Text ("Beep")) {
                    Text ("Silent").tag (BeepKind.silent)
                    Text ("Beep").tag (BeepKind.beep)
                    Text ("Vibrate").tag (BeepKind.vibrate)
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
