//
//  HostEditView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

var platformToIcon: [String:String] = [
    "Default": "",
    "Fedora": "fedora",
    "Linux": "linux",
    "Raspbian": "raspberry-pi",
    "Red Hat": "redhat",
    "SUSE": "suse",
    "Ubuntu": "ubuntu",
    "Windows": "windows"
]

// Ordered in ideal sorting order
var platformsIconKeys = [
    "Default",
    "Linux",
    "Ubuntu",
    "Mac",
    "Windows",
    "Raspbian",
    "Red Hat",
    "Fedora",
    "SUSE"
]

var platformsSorted: [String] {
    get {
        platformToIcon.keys.sorted()
    }
}

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

//extension View {
//    @ViewBuilder func `if`<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T : View {
//        if condition {
//            transform(self)
//        } else {
//            self
//        }
//    }
//}

struct PlatformSelector: View {
    @Binding var platformName: String
    var callback: (_ platformName: String) -> ()
    
    var body: some View {
        ScrollView (.horizontal, showsIndicators: false) {
            HStack {
                ForEach (platformsIconKeys, id: \.self) { t in
                    PlatformPreview (name: t, icon: platformToIcon [t], selected: self.platformName == platformToIcon[t])
                        .padding([.top], 3)
                        .background((self.platformName == platformToIcon[t] ? Color.accentColor : Color.clear).opacity(0.2))
                        .onTapGesture {
                            self.platformName = t
                            self.callback (t)
                        }
                }
            }
        }
    }
}

struct HostEditView: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @State var alertClash: Bool = false
    @State var host: Host
    @Binding var showingModal: Bool
    @State var selectedKey = 0
    @State var originalAlias: String = ""
    @State var keySelectorIsActive: Bool = false
    @State var showingPassword: Bool = false
    @State var platformIndex: Int = 0
    @State var themeName = ""
    @State var platformName = ""
    
    var disableSave: Bool {
        let alias = $host.alias.wrappedValue
        let hostname = $host.hostname.wrappedValue
        return alias == "" || hostname == ""
    }
    
    func saveAndLeave ()
    {
        self.host.lastUsed = Date()
        self.host.hostKindGuess = platformToIcon [platformsSorted [$platformIndex.wrappedValue]] ?? ""
        store.save (host: self.host)
        
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
        self.host.sshKey = chosenKey.id
        keySelectorIsActive = false
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text ("Alias")//.modifier(PrimaryLabel())
                        TextField("name", text: self.$host.alias)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                        
                    }
                    HStack {
                        Text ("Host")//.modifier(PrimaryLabel())
                        TextField ("192.168.1.100", text: self.$host.hostname)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                    }

                    HStack {
                        Text ("Username").modifier(PrimaryLabel())
                        TextField ("user", text: self.$host.username)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                    }
                    HStack {
                        Text ("Authentication")
                        Spacer ()
                        Picker(selection: self.$host.usePassword, label: Text ("Auth")) {
                            Text ("Password")
                                .tag (true)
                            Text ("SSH Key")
                                .tag (false)
                        }.pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                    }
                    if self.$host.usePassword.wrappedValue {
                        HStack {
                            Text ("Password").modifier(PrimaryLabel())
                            
                            if showingPassword {
                                TextField ("•••••••", text: self.$host.password)
                                    .multilineTextAlignment(.trailing)
                                    .autocapitalization(.none)
                            } else {
                                SecureField ("•••••••", text: self.$host.password)
                                    .multilineTextAlignment(.trailing)
                                    .autocapitalization(.none)
                            }
                            
                            Button (action: { self.showingPassword.toggle () }, label: {
                                Text (self.showingPassword ? "HIDE" : "SHOW").foregroundColor(Color (UIColor.link))
                            })
                        }
                    } else {
                        HStack {
                            Text ("SSH Key")
                            
                            if self.store.hostHasValidKey(host: self.host) {
                                Spacer ()
                                Text (self.store.getSshDisplayName (forHost: host))
                                Image (systemName: "multiply.circle.fill")
                                    .onTapGesture {
                                        self.host.sshKey = nil
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
                
                Section (header: Text ("Style")){
                    PlatformSelector(platformName: $platformName) {x in }
                    HStack {
                        Text ("Host Icon")
                        Picker(selection: $platformIndex, label: Text ("")){
                            ForEach(0..<platformsSorted.count) { idx in
                                HStack {
                                    Image(platformToIcon [platformsSorted[idx]]!)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 28)
                                    Text (platformsSorted[idx])
                                }
                            }
                        }
                    }
                    
                    ThemeSelector(themeName: self.$host.style, showDefault: true) { t in }
                }
                Section (header: Text ("Other Options")) {
                    HStack {
                        Text ("Port").modifier(PrimaryLabel())
                        TextField ("22", value: self.$host.port, formatter: NumberFormatter ())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                   
                    Text ("Encoding")
                }
            }
            .navigationBarItems(
                leading:  Button ("Cancel") {
                    self.showingModal.toggle()
                },
                trailing: Button("Save") {
                    if self.host.alias != self.originalAlias && self.store.hasHost(withAlias: self.$host.wrappedValue.alias) {
                        self.alertClash = true
                    } else {
                        self.saveAndLeave ()
                    }
                }.disabled (disableSave))
                .alert(isPresented: self.$alertClash) {
                    Alert (title: Text ("Duplicate Host"),
                           message: Text ("There is already a host with the alias \(host.alias) declared, do you want to replace that host definition with this one?"), primaryButton: .cancel(), secondaryButton: .destructive(Text ("Proceed")) {
                            self.saveAndLeave ()
                        })
            }
                // This is needed to prevent a warning from UIKit about autolayout
                //https://gist.github.com/migueldeicaza/ed0ba152159817e0c4a1fd429b596573
            .disableAutocorrection(true)
        }.onAppear() {
            self.themeName = self.host.style
            self.platformName = self.host.hostKindGuess
            self.originalAlias = self.host.alias
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
