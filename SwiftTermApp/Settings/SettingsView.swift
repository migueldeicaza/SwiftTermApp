//
//  SettingsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/28/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import SwiftTerm
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

// Converts a SwiftTerm.Color into a SwiftUI.Color
func term2ui (_ stcolor: SwiftTerm.Color) -> SwiftUI.Color {
    SwiftUI.Color (red: Double (stcolor.red)/65535.0,
                   green: Double (stcolor.green)/65535.0,
                   blue: Double (stcolor.blue)/65535.0)
}

struct ColorSwatch: View {
    var color: SwiftTerm.Color
    
    var body: some View {
        Rectangle ()
            .fill (term2ui (color))
            .frame (width: 9, height: 9)
            .shadow(radius: 1)
    }
}


struct ThemeSelector: View {
    var themeColor: ThemeColor
    var name: String
    var body: some View {
        ZStack {
            Rectangle ()
                .fill (term2ui(themeColor.background))
             
            VStack (spacing: 6){
                HStack {
                    Text (name)
                        .padding([.leading, .top], 4)
                        .foregroundColor(term2ui(themeColor.foreground))
                    Spacer ()
                }
                HStack (spacing: 5){
                    ForEach (0..<7) { x in
                        ColorSwatch (color: self.themeColor.ansi [x])
                    }
                }
                HStack (spacing: 5){
                    ForEach (8..<15) { x in
                        ColorSwatch (color: self.themeColor.ansi [x])
                    }
                }
            }
        }
        .frame(width: 120, height: 70)
        .border(Color.black)
    }
}
struct AppearanceSelector: View {
    var body: some View {
        Text ("Theme selector")
    }
}

struct SettingsView: View {
    @State var fontIdx = 0
    @ObservedObject var gset = settings
    var tc = ThemeColor.fromXrdb (txt: material)!
    var tc2 = ThemeColor.fromXrdb (txt: ocean)!
    var tc3 = ThemeColor.fromXrdb (txt: adventureTime)!
    
    var body: some View {
        NavigationView {
            Form {
                HStack {
                    ThemeSelector (themeColor: tc, name: "Material")
                    ThemeSelector (themeColor: tc2, name: "Ocean")
                    ThemeSelector (themeColor: tc3, name: "Adventure Time")
                }
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
        Group {
            ThemeSelector(themeColor: ThemeColor.fromXrdb (txt: material)!, name: "Test")
            SettingsView()
        }
    }
}

let material = """
#define Ansi_0_Color #212121
#define Ansi_1_Color #b7141f
#define Ansi_10_Color #7aba3a
#define Ansi_11_Color #ffea2e
#define Ansi_12_Color #54a4f3
#define Ansi_13_Color #aa4dbc
#define Ansi_14_Color #26bbd1
#define Ansi_15_Color #d9d9d9
#define Ansi_2_Color #457b24
#define Ansi_3_Color #f6981e
#define Ansi_4_Color #134eb2
#define Ansi_5_Color #560088
#define Ansi_6_Color #0e717c
#define Ansi_7_Color #efefef
#define Ansi_8_Color #424242
#define Ansi_9_Color #e83b3f
#define Background_Color #eaeaea
#define Bold_Color #b7141f
#define Cursor_Color #16afca
#define Cursor_Text_Color #2e2e2d
#define Foreground_Color #232322
#define Selected_Text_Color #4e4e4e
#define Selection_Color #c2c2c2
"""

let ocean = """
#define Ansi_0_Color #000000
#define Ansi_1_Color #990000
#define Ansi_10_Color #00d900
#define Ansi_11_Color #e5e500
#define Ansi_12_Color #0000ff
#define Ansi_13_Color #e500e5
#define Ansi_14_Color #00e5e5
#define Ansi_15_Color #e5e5e5
#define Ansi_2_Color #00a600
#define Ansi_3_Color #999900
#define Ansi_4_Color #0000b2
#define Ansi_5_Color #b200b2
#define Ansi_6_Color #00a6b2
#define Ansi_7_Color #bfbfbf
#define Ansi_8_Color #666666
#define Ansi_9_Color #e50000
#define Background_Color #224fbc
#define Bold_Color #ffffff
#define Cursor_Color #7f7f7f
#define Cursor_Text_Color #ffffff
#define Foreground_Color #ffffff
#define Selected_Text_Color #ffffff
#define Selection_Color #216dff

"""

let adventureTime = """
#define Ansi_0_Color #050404
#define Ansi_1_Color #bd0013
#define Ansi_10_Color #9eff6e
#define Ansi_11_Color #efc11a
#define Ansi_12_Color #1997c6
#define Ansi_13_Color #9b5953
#define Ansi_14_Color #c8faf4
#define Ansi_15_Color #f6f5fb
#define Ansi_2_Color #4ab118
#define Ansi_3_Color #e7741e
#define Ansi_4_Color #0f4ac6
#define Ansi_5_Color #665993
#define Ansi_6_Color #70a598
#define Ansi_7_Color #f8dcc0
#define Ansi_8_Color #4e7cbf
#define Ansi_9_Color #fc5f5a
#define Background_Color #1f1d45
#define Bold_Color #bd0013
#define Cursor_Color #efbf38
#define Cursor_Text_Color #08080a
#define Foreground_Color #f8dcc0
#define Selected_Text_Color #f3d9c4
#define Selection_Color #706b4e
"""
