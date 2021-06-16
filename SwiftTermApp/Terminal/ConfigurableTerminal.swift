//
//  ConfigurableTerminal.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/21/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI


struct RunningTerminalConfig: View {
    var host: Host
    @Binding var showingModal: Bool
    @State var style: String = ""
    @State var background: String = ""
    
    func save () {
        host.style = style
        host.background = background
        print ("Background set is: \(background)")
        DataStore.shared.saveState()
        DataStore.shared.runtimeVisibleChanges.send(host)
    }
    
    var body: some View {
        NavigationView {
            
            Form {
                ThemeSelector(themeName: $style, showDefault: true) { t in
                    style = t
                }
                BackgroundSelector (backgroundStyle: $background, showDefault: true)
            }
            .toolbar {
                ToolbarItem (placement: .navigationBarLeading) {
                    Button ("Cancel") {
                        self.showingModal = false
                    }
                }
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button("Save") {
                        save ()
                        self.showingModal = false
                    }
                }
            }
        }
        .onAppear() {
            style = host.style
            background = host.background
        }
    }
}

// For full screen Solution might be to use an external host UIViewController:
// https://gist.github.com/timothycosta/a43dfe25f1d8a37c71341a1ebaf82213
// https://stackoverflow.com/questions/56756318/swiftui-presentationbutton-with-modal-that-is-full-screen


struct ConfigurableUITerminal: View {
    var host: Host!
    var terminalView: SshTerminalView!
    var createNew: Bool = false
    var interactive: Bool = true
    @State var showConfig: Bool = false
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        SwiftUITerminal(host: host, existing: terminalView, createNew: createNew, interactive: interactive)
            .navigationTitle (Text (host.alias))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem (placement: .navigationBarTrailing) {
                    HStack {
                        Button (action: { self.showConfig = true }) {
                            Image(systemName: "gearshape")
                        }
                        Button (action: { self.hideKeyboard() }) {
                            Image(systemName: "keyboard")
                        }
                    }
                }
            }
            .sheet (isPresented: $showConfig) {
                RunningTerminalConfig (host: host, showingModal: $showConfig)
            }
    }
}

struct ConfigurableUITerminal_Previews: PreviewProvider {
    static var previews: some View {
        WrapperView ()
    }
    
    struct WrapperView: View {
        @State var host = Host ()
        @State var showingModal = false
        
        var body: some View {
            NavigationView {
                VStack {
                    ConfigurableUITerminal(host: host)
                    Text ("Below is the configuration")
                    RunningTerminalConfig(host: host, showingModal: $showingModal)
                }
            }
        }
    }
}
