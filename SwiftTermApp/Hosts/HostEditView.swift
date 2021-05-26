//
//  HostEditView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

var platformToHuman: [String:String] = [
    "": "Generic",
    "fedora": "Fedora",
    "linux": "Linux",
    "raspberry-pi": "Raspbian",
    "redhat": "Red Hat",
    "suse": "SUSE",
    "ubuntu": "Ubuntu",
    "windows": "Windows",
    "apple": "Mac"
]

// Ordered in ideal sorting order
var manualOrderPlatformList = [
    "",
    "linux",
    "ubuntu",
    "apple",
    "windows",
    "raspberry-pi",
    "redhat",
    "fedora",
    "suse"
]

struct PlatformPreview: View {
    var name: String
    var icon: String?
    var selected: Bool
    
    var body: some View {
        VStack {
            if icon == nil || icon == "" {
                Image (systemName: "desktopcomputer")
                    .resizable()
                    .frame(width: 40, height: 40)
            } else {
                Image (self.icon!)
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            Text (name)
                .lineLimit(2)
                .frame(width: 60, height: 20, alignment: .top)
                .font(.footnote)
        }
    }
}

struct PlatformSelector: View {
    @Binding var platformName: String
    var callback: (_ platformName: String) -> ()
    
    var body: some View {
        ScrollView (.horizontal, showsIndicators: false) {
            HStack {
                ForEach (manualOrderPlatformList, id: \.self) { t in
                    PlatformPreview (name: platformToHuman [t] ?? "BUG", icon: t, selected: self.platformName == t)
                        .padding([.top], 3)
                        .background((self.platformName == t ? Color.accentColor : Color.clear).opacity(0.2))
                        .onTapGesture {
                            self.platformName = t
                            self.callback (t)
                        }
                }
            }
        }
    }
}

//
// This needs to use AnyViews, because I need to apply the optional
// brightness to the asset images to show up in the same style as
// the i
struct PlatformSelectorIcon: View {
    @Environment(\.colorScheme) var colorScheme
    var platformName: String
    
    var body: some View {
        if platformName == "" {
            return AnyView (Image (systemName: "desktopcomputer")
                .resizable()
            .scaledToFit()
            .frame(maxHeight: 20))
        } else {
            return AnyView (Image(platformName)
                .resizable()
            .scaledToFit()
                .frame(maxHeight: 24)
                .brightness(colorScheme == .dark ? 0.6 : 0.5))
        }
    }
}

struct HostIconSelector: View {
    @Binding var platformName: String
    
    var body: some View {
        HStack {
            Picker(selection: $platformName, label: Text ("Host Icon")){
                ForEach(manualOrderPlatformList, id: \.self) { name in
                    HStack {
                        PlatformSelectorIcon (platformName: name)
                        Text (platformToHuman [name] ?? "BUG" + name)
                    }.tag (name)
                }
            }
        }
    }
}

struct HostEditView: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @State var alertClash: Bool = false
    var _host: Host
    @Binding var showingModal: Bool
    @State var selectedKey = 0
    @State var keySelectorIsActive: Bool = false
    @State var showingPassword: Bool = false

    @State var originalAlias: String = ""
    @State var alias = ""
    @State var hostname = ""
    @State var backspaceAsControlH = false
    @State var style = ""
    @State var backgroundStyle = ""
    @State var hostKindGuess = ""
    @State var username = ""
    @State var password = ""
    @State var port = 22
    @State var usePassword = false
    @State var sshKey: UUID? = nil
    
    init (host: Host, showingModal: Binding<Bool>){
        self._host = host
        self._showingModal = showingModal
        
        _originalAlias = State (initialValue: host.alias)
        _alias = State (initialValue: host.alias)
        _hostname = State (initialValue: host.hostname)
        _backspaceAsControlH = State (initialValue: host.backspaceAsControlH)
        _port = State (initialValue: host.port)
        _usePassword = State (initialValue: host.usePassword)
        _username = State (initialValue: host.username)
        _password = State (initialValue: host.password)
        _hostKindGuess = State (initialValue: host.hostKindGuess)
        _style = State (initialValue: host.style)
        _backgroundStyle = State (initialValue: host.background)
        _sshKey = State (initialValue: host.sshKey)
    }
    
    var disableSave: Bool {
        return alias == "" || hostname == "" || username == ""
    }
    
    func saveAndLeave ()
    {
        _host.lastUsed = Date()
        _host.alias = alias
        _host.hostname = hostname
        _host.backspaceAsControlH = backspaceAsControlH
        _host.port = port
        _host.usePassword = usePassword
        _host.hostKindGuess = hostKindGuess
        _host.background = backgroundStyle
        _host.style = style
        _host.sshKey = sshKey
        
        store.save (host: _host)
        
        // Delaying the dismiss operation seems to prevent the SwiftUI crash:
        // https://stackoverflow.com/questions/58404725/why-does-my-swiftui-app-crash-when-navigating-backwards-after-placing-a-navigat
        //
        // Note that it still seems to sometimes go back to the toplevel (???) and
        // sometimes stay where we weref
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingModal = false
        }
        
    }
    
    func assignKey (chosenKey: Key)
    {
        sshKey = chosenKey.id
        keySelectorIsActive = false
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text ("Alias")//.modifier(PrimaryLabel())
                        TextField("name", text: self.$alias)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                        
                    }
                    HStack {
                        Text ("Host")//.modifier(PrimaryLabel())
                        TextField ("192.168.1.100", text: self.$hostname)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                    }

                    HStack {
                        Text ("Username").modifier(PrimaryLabel())
                        TextField ("user", text: self.$username)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                    }
                    HStack {
                        Text ("Authentication")
                        Spacer ()
                        Picker(selection: self.$usePassword, label: Text ("Auth")) {
                            Text ("Password")
                                .tag (true)
                            Text ("SSH Key")
                                .tag (false)
                        }.pickerStyle(SegmentedPickerStyle())
                            .frame(width: 160)
                    }
                    if self.$usePassword.wrappedValue {
                        HStack {
                            Text ("Password").modifier(PrimaryLabel())
                            
                            if showingPassword {
                                TextField ("•••••••", text: self.$password)
                                    .multilineTextAlignment(.trailing)
                                    .autocapitalization(.none)
                            } else {
                                SecureField ("•••••••", text: self.$password)
                                    .multilineTextAlignment(.trailing)
                                    .autocapitalization(.none)
                            }
                            
                            Button (action: { self.showingPassword.toggle () }, label: {
                                Image(systemName: self.showingPassword ? "eye.slash" : "eye")
                                    
                            })
                        }
                    } else {
                        HStack {
                            Text ("SSH Key")
                            
                            if self.store.hostHasValidKey(host: self._host) {
                                Spacer ()
                                Text (self.store.getSshDisplayName (forHost: _host))
                                Image (systemName: "multiply.circle.fill")
                                    .onTapGesture {
                                        self.sshKey = nil
                                    }
                            } else {
                                NavigationLink(destination: KeyManagementView(action: assignKey),
                                               isActive: self.$keySelectorIsActive) {
                                    Text ("")
                                }.isDetailLink (false)
                            }
                        }
                    }
                }
                
                Section (header: Text ("Appearance")){
                    ThemeSelector(themeName: self.$style, showDefault: true) { t in self.style = t }
                    BackgroundSelector (backgroundStyle: self.$backgroundStyle, showDefault: true)
                    
                    //PlatformSelector(platformName: $platformName) {x in }
                    HostIconSelector (platformName: $hostKindGuess)
                    
                }
                Section (header: Text ("Other Options")) {
                    HStack {
                        Text ("Port").modifier(PrimaryLabel())
                        TextField ("22", value: self.$port, formatter: NumberFormatter ())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading:  Button ("Cancel") {
                    self.showingModal.toggle()
                },
                trailing: Button("Save") {
                    if self.alias != self.originalAlias && self.store.hasHost(withAlias: self.alias) {
                        self.alertClash = true
                    } else {
                        self.saveAndLeave ()
                    }
                }.disabled (disableSave))
                .alert(isPresented: self.$alertClash) {
                    Alert (title: Text ("Duplicate Host"),
                           message: Text ("There is already a host with the alias \(alias) declared, do you want to replace that host definition with this one?"), primaryButton: .cancel(), secondaryButton: .destructive(Text ("Proceed")) {
                            self.saveAndLeave ()
                        })
            }
                // This is needed to prevent a warning from UIKit about autolayout
                //https://gist.github.com/migueldeicaza/ed0ba152159817e0c4a1fd429b596573
            .disableAutocorrection(true)
        }
    }
}

struct HostEditView_Previews: PreviewProvider {
    
    static var previews: some View {
        WrapperView ()
    }
    
    struct WrapperView: View {
        @State var host = Host ()
        
        var body: some View {
            HostEditView(host: host, showingModal: .constant(true))
        }
    }
}
