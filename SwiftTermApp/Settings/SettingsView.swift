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
    var defaults = UserDefaults (suiteName: "SwiftTermApp")

    func updateKeepOn () {
        UIApplication.shared.isIdleTimerDisabled = keepOn && Connections.shared.connections.count > 0
    }
    
    @Published var keepOn: Bool = true {
        didSet {
            updateKeepOn ()

            defaults?.set (keepOn, forKey: "keepOn")
        }
    }
    
    @Published var locationTrack: Bool = false {
        didSet {
            if locationTrack {
                locationTrackerStart()
            } else {
                locationTrackerStop()
            }
            defaults?.set (keepOn, forKey: "locationTrack")
        }
    }
    
    @Published var beepConfig: BeepKind = .vibrate {
        didSet {
            defaults?.set (beepConfig.rawValue, forKey: "beepConfig")
        }
    }
    @Published var themeName: String = "Pro" {
        didSet {
            defaults?.set (themeName, forKey: "theme")
        }
    }
    @Published var fontName: String = fontNames [0] {
        didSet {
            defaults?.set (fontName, forKey: "fontName")
        }
    }
    @Published var fontSize: CGFloat = 10 {
        didSet {
            defaults?.set (fontSize, forKey: "fontSize")
        }
    }
    @Published var backgroundStyle: String = "" {
        didSet {
            defaults?.set (backgroundStyle, forKey: "backgroundStyle")
        }
    }

    func getTheme (themeName: String? = nil) -> ThemeColor
    {
        if let t = themes.first(where: { $0.name == themeName ?? self.themeName }) {
            return t
        }
        return themes [0]
    }
    
    init () {
        keepOn = defaults?.bool(forKey: "keepOn") ?? true
        beepConfig = BeepKind (rawValue: defaults?.string(forKey: "beepConfig") ?? "vibrate") ?? .vibrate
        themeName = defaults?.string (forKey: "theme") ?? "Pro"
        fontName = defaults?.string (forKey: "fontName") ?? "Courier"
        let fsize = defaults?.double(forKey: "fontSize") ?? 11
        
        fontSize = CGFloat (fsize == 0.0 ? 11.0 : max (5.0, fsize))
        backgroundStyle = defaults?.string (forKey: "backgroundStyle") ?? ""
    }
}

var settings = Settings()

var fontNames: [String] = ["Courier", "Courier New", "Menlo", "SF Mono"]

enum BeepKind: String {
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
    var title: String? = nil
    var selected: Bool = false
    
    var body: some View {
        ZStack {
            Rectangle ()
                .fill (term2ui(themeColor.background))
             
            VStack (spacing: 6){
                HStack (alignment: .firstTextBaseline) {
                    Text (title ?? themeColor.name)
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
    var fontName: String
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
            .font (.custom(fontName, size: size))
        .padding()
    
    }
}

struct ThemeSelector: View {
    @Binding var themeName: String
    @State var showDefault = false
    var callback: (_ themeName: String) -> ()
    
    var body: some View {
        ScrollView (.horizontal, showsIndicators: false) {
            HStack {
                if showDefault {
                    ThemePreview (themeColor: settings.getTheme(), title: "Default")
                        .padding(1)
                        .border(self.themeName == "" ? Color.accentColor : Color.clear, width: 2)
                        .onTapGesture {
                            self.themeName = ""
                            self.callback ("")
                    }
                }
                ForEach (themes, id: \.self) { t in
                    ThemePreview (themeColor: t)
                        .padding(1)
                        .border(self.themeName == t.name ? Color.accentColor : Color.clear, width: 2)
                        .onTapGesture {
                            self.themeName = t.name
                            //self.callback (t.name)
                    }
                }
            }
        }
    }
}

struct FontSelector: View {
    @Binding var fontName: String
    
    var body: some View {
        Picker(selection: $fontName, label: Text ("Font")) {
            ForEach (fontNames, id: \.self) { fontName in
                Text (fontName)
                    .font(.custom(fontName, size: 17))
                    .tag (fontName)
            }
        }
    }
}

struct FontSizeSelector: View {
    var fontName: String
    @Binding var fontSize: CGFloat
    
    var fontSizes: [CGFloat] = [8, 10, 11, 12, 14, 18]

    var body: some View {
        HStack (alignment: .center){
            ForEach (fontSizes, id: \.self) { size in
                FontSize (fontName: self.fontName, size: size, currentSize: self.$fontSize)
                    .onTapGesture {
                        self.fontSize = size
                }
            }
        }
    }
}

var shaders = ["digitalbrain_fragment_texture", "plasma_fragment_texture", "starnest_fragment_texture"]
var shaderToHuman = [
    "plasma_fragment_texture": "Plasma",
    "starnest_fragment_texture": "Star Nest",
    "digitalbrain_fragment_texture": "Digital Brain"
]

struct LiveBackgroundSelector: View {
    @Binding var selected: String
    
    var body: some View {
        ScrollView (.horizontal, showsIndicators: false) {
            HStack {
                ForEach (shaders, id: \.self) { name in
                    
                    MetalView(shaderFunc: name)
                        .frame(width: 120, height: 90)
                    .border (self.selected == name ? Color.accentColor : Color.clear, width: 2)
                        .onTapGesture {
                            self.selected = name
                        }
                    .overlay (
                        Text (shaderToHuman [name] ?? name)
                            .shadow(color: Color.red, radius: 10, x: 5, y: 5)
                            .foregroundColor(Color.white)
                            
                        .padding(8)
                        , alignment: .topLeading)
                }
            }
        }
    }
}

/// Shows the background selector with the labels:
/// [Default|Solid|Live]
///
/// The "Default" label is only shown if showDefault is true, otherwise it is not shown
/// 
struct BackgroundSelector: View {
    @Binding var backgroundStyle: String
    @State var backgroundKind: Int = 0
    
    // If sets to true shows a selector "Default"
    @State var showDefault: Bool
    
    var body: some View {
        HStack {
            VStack {
                HStack {
                    Text ("Background")
                    Spacer ()
                    Picker(selection: $backgroundKind, label: Text ("Background Style")){
                        if showDefault {
                            Text ("Default").tag (0)
                        }
                        Text ("Solid").tag (1)
                        Text ("Live").tag (2)
                    }
                    .pickerStyle (SegmentedPickerStyle ())
                    .onChange(of: backgroundKind) { _ in
                        if backgroundKind == 0 {
                            backgroundStyle = "default"
                        } else if backgroundKind == 1 {
                            backgroundStyle = ""
                        } 
                    }
                }
                if backgroundKind == 2 {
                    LiveBackgroundSelector (selected: $backgroundStyle)
                }
            }
        }.onAppear {
            if self.backgroundStyle == "default" {
                self.backgroundKind = self.showDefault ? 0 : 1
            } else {
                self.backgroundKind = self.backgroundStyle == "" ? 1 : 2
            }
        }
    }
}

struct SettingsViewCore: View {
    @Binding var themeName: String
    @Binding var fontName: String
    @Binding var fontSize: CGFloat
    @Binding var keepOn: Bool
    @Binding var locationTrack: Bool
    @Binding var beepConfig: BeepKind
    @Binding var backgroundStyle: String
    
    var body: some View {
        return Form {
            Section (header: Text ("Appearance")){
                
                // Theme selector
                VStack (alignment: .leading){
                    Text ("Color Theme")
                    ThemeSelector (themeName: $themeName) {
                        settings.themeName = $0
                        
                    }
                }
                FontSelector (fontName: $fontName)
                FontSizeSelector (fontName: fontName, fontSize: $fontSize)
                BackgroundSelector (backgroundStyle: $backgroundStyle, showDefault: false)
            }
            Section {
                Toggle(isOn: $keepOn) {
                    VStack (alignment: .leading){
                        Text ("Keep Display On")
                        Text ("Prevents sleep mode from activating while you are connected").font (.subheadline).foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $locationTrack) {
                    VStack (alignment: .leading){
                            Text ("Track Location")
                        Text ("Tracks your location to keep the terminal running in the background, you can review the locations from the History tab").font (.subheadline).foregroundColor(.secondary)
                    }
                }

                // Keyboard
                Picker (selection: $beepConfig, label: Text ("Beep")) {
                    Text ("Silent").tag (BeepKind.silent)
                    Text ("Beep").tag (BeepKind.beep)
                    Text ("Vibrate").tag (BeepKind.vibrate)
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var gset = settings
    
    var body: some View {
        SettingsViewCore (themeName: $gset.themeName,
                          fontName: $gset.fontName,
                          fontSize: $gset.fontSize,
                          keepOn: $gset.keepOn,
                          locationTrack: $gset.locationTrack,
                          beepConfig: $gset.beepConfig,
                          backgroundStyle: $gset.backgroundStyle)
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            SettingsView()
            ThemePreview(themeColor: ThemeColor.fromXrdb (title: "Material", xrdb: themeMaterial)!)
        }
    }
}

let themes: [ThemeColor] = [
    ThemeColor.fromXrdb (title: "Adventure Time", xrdb: themeAdventureTime)!,
    ThemeColor.fromXrdb (title: "Dark", xrdb: themeBuiltinDark)!,
    ThemeColor.fromXrdb (title: "Django", xrdb: themeDjango)!,
    ThemeColor.fromXrdb (title: "Light", xrdb: themeBuiltinLight)!,
    ThemeColor.fromXrdb (title: "Material", xrdb: themeMaterial)!,
    ThemeColor.fromXrdb (title: "Ocean", xrdb: themeOcean)!,
    ThemeColor.fromXrdb (title: "Solarized Dark", xrdb: themeSolarizedDark)!,
    ThemeColor.fromXrdb (title: "Solarized Light", xrdb: themeSolarizedLight)!,
    ThemeColor.fromXrdb (title: "Tango Dark", xrdb: themeTangoDark)!,
    ThemeColor.fromXrdb (title: "Tango Light", xrdb: themeTangoLight)!,
    ThemeColor.fromXrdb (title: "Pro", xrdb: themePro)!,
]

let themeBuiltinDark = """
#define Ansi_0_Color #000000
#define Ansi_1_Color #bb0000
#define Ansi_10_Color #55ff55
#define Ansi_11_Color #ffff55
#define Ansi_12_Color #5555ff
#define Ansi_13_Color #ff55ff
#define Ansi_14_Color #55ffff
#define Ansi_15_Color #ffffff
#define Ansi_2_Color #00bb00
#define Ansi_3_Color #bbbb00
#define Ansi_4_Color #0000bb
#define Ansi_5_Color #bb00bb
#define Ansi_6_Color #00bbbb
#define Ansi_7_Color #bbbbbb
#define Ansi_8_Color #555555
#define Ansi_9_Color #ff5555
#define Background_Color #000000
#define Badge_Color #ff0000
#define Bold_Color #ffffff
#define Cursor_Color #bbbbbb
#define Cursor_Guide_Color #a6e8ff
#define Cursor_Text_Color #ffffff
#define Foreground_Color #bbbbbb
#define Link_Color #0645ad
#define Selected_Text_Color #000000
#define Selection_Color #b5d5ff
"""

let themeBuiltinLight = """
#define Ansi_0_Color #000000
#define Ansi_1_Color #bb0000
#define Ansi_10_Color #55ff55
#define Ansi_11_Color #ffff55
#define Ansi_12_Color #5555ff
#define Ansi_13_Color #ff55ff
#define Ansi_14_Color #55ffff
#define Ansi_15_Color #ffffff
#define Ansi_2_Color #00bb00
#define Ansi_3_Color #bbbb00
#define Ansi_4_Color #0000bb
#define Ansi_5_Color #bb00bb
#define Ansi_6_Color #00bbbb
#define Ansi_7_Color #bbbbbb
#define Ansi_8_Color #555555
#define Ansi_9_Color #ff5555
#define Background_Color #ffffff
#define Badge_Color #ff0000
#define Bold_Color #000000
#define Cursor_Color #000000
#define Cursor_Guide_Color #a6e8ff
#define Cursor_Text_Color #ffffff
#define Foreground_Color #000000
#define Link_Color #0645ad
#define Selected_Text_Color #000000
#define Selection_Color #b5d5ff
"""

let themeSolarizedDark = """
#define Ansi_0_Color #073642
#define Ansi_1_Color #dc322f
#define Ansi_10_Color #586e75
#define Ansi_11_Color #657b83
#define Ansi_12_Color #839496
#define Ansi_13_Color #6c71c4
#define Ansi_14_Color #93a1a1
#define Ansi_15_Color #fdf6e3
#define Ansi_2_Color #859900
#define Ansi_3_Color #b58900
#define Ansi_4_Color #268bd2
#define Ansi_5_Color #d33682
#define Ansi_6_Color #2aa198
#define Ansi_7_Color #eee8d5
#define Ansi_8_Color #002b36
#define Ansi_9_Color #cb4b16
#define Background_Color #002b36
#define Badge_Color #ff2600
#define Bold_Color #93a1a1
#define Cursor_Color #839496
#define Cursor_Guide_Color #b3ecff
#define Cursor_Text_Color #073642
#define Foreground_Color #839496
#define Link_Color #005cbb
#define Selected_Text_Color #93a1a1
#define Selection_Color #073642
"""

let themeSolarizedLight = """
#define Ansi_0_Color #073642
#define Ansi_1_Color #dc322f
#define Ansi_10_Color #586e75
#define Ansi_11_Color #657b83
#define Ansi_12_Color #839496
#define Ansi_13_Color #6c71c4
#define Ansi_14_Color #93a1a1
#define Ansi_15_Color #fdf6e3
#define Ansi_2_Color #859900
#define Ansi_3_Color #b58900
#define Ansi_4_Color #268bd2
#define Ansi_5_Color #d33682
#define Ansi_6_Color #2aa198
#define Ansi_7_Color #eee8d5
#define Ansi_8_Color #002b36
#define Ansi_9_Color #cb4b16
#define Background_Color #fdf6e3
#define Badge_Color #ff2600
#define Bold_Color #586e75
#define Cursor_Color #657b83
#define Cursor_Guide_Color #b3ecff
#define Cursor_Text_Color #eee8d5
#define Foreground_Color #657b83
#define Link_Color #005cbb
#define Selected_Text_Color #586e75
#define Selection_Color #eee8d5

"""
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

let themeDjango = """
#define Ansi_0_Color #000000
#define Ansi_1_Color #fd6209
#define Ansi_10_Color #73da70
#define Ansi_11_Color #ffff94
#define Ansi_12_Color #568264
#define Ansi_13_Color #ffffff
#define Ansi_14_Color #cfffd1
#define Ansi_15_Color #ffffff
#define Ansi_2_Color #41a83e
#define Ansi_3_Color #ffe862
#define Ansi_4_Color #245032
#define Ansi_5_Color #f8f8f8
#define Ansi_6_Color #9df39f
#define Ansi_7_Color #ffffff
#define Ansi_8_Color #323232
#define Ansi_9_Color #ff943b
#define Background_Color #0b2f20
#define Bold_Color #f8f8f8
#define Cursor_Color #336442
#define Cursor_Text_Color #f8f8f8
#define Foreground_Color #f8f8f8
#define Selected_Text_Color #f8f8f8
#define Selection_Color #245032
"""

let themeTangoDark = """
#define Ansi_0_Color #000000
#define Ansi_1_Color #cc0000
#define Ansi_10_Color #8ae234
#define Ansi_11_Color #fce94f
#define Ansi_12_Color #729fcf
#define Ansi_13_Color #ad7fa8
#define Ansi_14_Color #34e2e2
#define Ansi_15_Color #eeeeec
#define Ansi_2_Color #4e9a06
#define Ansi_3_Color #c4a000
#define Ansi_4_Color #3465a4
#define Ansi_5_Color #75507b
#define Ansi_6_Color #06989a
#define Ansi_7_Color #d3d7cf
#define Ansi_8_Color #555753
#define Ansi_9_Color #ef2929
#define Background_Color #000000
#define Badge_Color #ff0000
#define Bold_Color #ffffff
#define Cursor_Color #ffffff
#define Cursor_Guide_Color #a6e8ff
#define Cursor_Text_Color #000000
#define Foreground_Color #ffffff
#define Link_Color #0645ad
#define Selected_Text_Color #000000
#define Selection_Color #b5d5ff
"""

let themeTangoLight = """
#define Ansi_0_Color #000000
#define Ansi_1_Color #cc0000
#define Ansi_10_Color #8ae234
#define Ansi_11_Color #fce94f
#define Ansi_12_Color #729fcf
#define Ansi_13_Color #ad7fa8
#define Ansi_14_Color #34e2e2
#define Ansi_15_Color #eeeeec
#define Ansi_2_Color #4e9a06
#define Ansi_3_Color #c4a000
#define Ansi_4_Color #3465a4
#define Ansi_5_Color #75507b
#define Ansi_6_Color #06989a
#define Ansi_7_Color #d3d7cf
#define Ansi_8_Color #555753
#define Ansi_9_Color #ef2929
#define Background_Color #ffffff
#define Badge_Color #ff0000
#define Bold_Color #000000
#define Cursor_Color #000000
#define Cursor_Guide_Color #a6e8ff
#define Cursor_Text_Color #ffffff
#define Foreground_Color #000000
#define Link_Color #0645ad
#define Selected_Text_Color #000000
#define Selection_Color #b5d5ff

"""
