//
//  SettingsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/28/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import SwiftTerm

// The application settings
class Settings: ObservableObject {
    @Published var keepOn: Bool = true {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
    }
    @Published var fontIdx: Int = 0
    @Published var beepConfig: BeepKind = .vibrate
    @Published var themeName: String = "Material"
    @Published var fontName: String = "Courier"
    @Published var fontSize: CGFloat = 10

    init () {}
}
var settings = Settings()

var fontNames: [String] = ["Courier", "Courier New", "Menlo"]

enum BeepKind {
    case silent
    case beep
    case vibrate
}

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
            .frame (width: 11, height: 11)
            .shadow(radius: 1)
    }
}


struct ThemePreview: View {
    var themeColor: ThemeColor
    var selected: Bool = false
    
    var body: some View {
        ZStack {
            Rectangle ()
                .fill (term2ui(themeColor.background))
             
            VStack (spacing: 6){
                HStack (alignment: .firstTextBaseline) {
                    Text (themeColor.name)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding([.leading, .top], 4)
                        .foregroundColor(term2ui(themeColor.foreground))
                    Spacer ()
                }.frame (height: 24)
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
        .border(selected ? Color.black : Color.clear)
    }
}

struct FontSize: View {
    @Binding var fontIdx: Int
    var size: CGFloat
    @Binding var currentSize: CGFloat
    
    var body: some View {
        Text ("Aa")
            .background(
                RoundedRectangle (cornerRadius: 10, style: .continuous)
                    .stroke(self.currentSize == size ? Color.accentColor : Color (#colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)), lineWidth: 2)
                    .frame (width: 40, height: 40)
                    //.border(Color.black, width: 1)
                    .foregroundColor(Color.red))
            .font (.custom(fontNames [fontIdx], size: size))
        .padding()
    
    }
}

struct AppearanceSelector: View {
    var body: some View {
        Text ("Theme selector")
    }
}

struct SettingsView: View {
    @State var fontIdx = 0
    @State var theme = themes [0]
    @ObservedObject var gset = settings
    @State var fontSize = settings.fontSize
    
    func fontName () -> String {
        return fontNames [fontIdx]
    }
    
    var fontSizes: [CGFloat] = [8, 10, 11, 12, 14, 18]
    
    var body: some View {
        NavigationView {
            Form {
                // Theme selector
                ScrollView (.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach (themes, id: \.self) { t in
                            ThemePreview (themeColor: t)
                                .padding(1)
                                .border(self.theme == t ? Color.accentColor : Color.clear, width: 2)
                                .onTapGesture {
                                    self.theme = t
                            }
                        }
                    }
                }
                
                // Font size selector
                HStack (alignment: .center){
                    ForEach (fontSizes.indices) { idx in
                        FontSize (fontIdx: self.$fontIdx, size: self.fontSizes [idx], currentSize: self.$fontSize)
                            .onTapGesture {
                                self.fontSize = self.fontSizes [idx]
                        }
                    }
                }
                Picker(selection: self.$fontIdx, label: Text ("Font")) {
                    ForEach (fontNames, id: \.self) { fontName in
                        Text (fontName)
                            .font(.custom(fontName, size: 17))
                            .tag (fontNames.firstIndex(of: fontName)!)
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
            ThemePreview(themeColor: ThemeColor.fromXrdb (title: "Material", xrdb: themeMaterial)!)
            SettingsView(fontIdx: 1, gset: settings)
        }
    }
}

let themes: [ThemeColor] = [
    ThemeColor.fromXrdb (title: "Pro", xrdb: themePro)!,
    ThemeColor.fromXrdb (title: "Material", xrdb: themeMaterial)!,
    ThemeColor.fromXrdb (title: "Ocean", xrdb: themeOcean)!,
    ThemeColor.fromXrdb (title: "Adventure Time", xrdb: themeAdventureTime)!
]

let themeMaterial = """
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

let themeOcean = """
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

let themeAdventureTime = """
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

let themePro = """
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
#define Ansi_4_Color #2009db
#define Ansi_5_Color #b200b2
#define Ansi_6_Color #00a6b2
#define Ansi_7_Color #bfbfbf
#define Ansi_8_Color #666666
#define Ansi_9_Color #e50000
#define Background_Color #000000
#define Bold_Color #ffffff
#define Cursor_Color #4d4d4d
#define Cursor_Text_Color #ffffff
#define Foreground_Color #f2f2f2
#define Selected_Text_Color #000000
#define Selection_Color #414141
"""
