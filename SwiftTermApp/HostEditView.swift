//
//  HostEditView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct HostEditView: View {
    @Binding var host: Host
    @Binding var showingModal: Bool
    
    var disableSave: Bool {
        let alias = $host.alias.wrappedValue
        let hostname = $host.hostname.wrappedValue
        return alias != "" && hostname != ""
    }
    
    var body: some View {
        //NavigationView {
            Form {
                Section {
                    HStack {
                        Text ("Alias")//.modifier(PrimaryLabel())
                        TextField("name", text: self.$host.alias)
                            .multilineTextAlignment(.trailing)

                    }
                    HStack {
                        Text ("Host")//.modifier(PrimaryLabel())
                        TextField ("192.168.1.100", text: self.$host.hostname)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text ("Port").modifier(PrimaryLabel())
                        TextField ("22", value: self.$host.port, formatter: NumberFormatter ())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section (header: Text ("Identity")) {
                    HStack {
                        Text ("User").modifier(PrimaryLabel())
                        TextField ("user", text: self.$host.username)
                            .multilineTextAlignment(.trailing)
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
                            SecureField ("•••••••", text: self.$host.username)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        HStack {
                            Text ("SSH Key").modifier(PrimaryLabel())
                        }
                    }
                }
                
                Section (header: Text ("Terminal Options")) {
                    Text ("Encoding")
                }
            }
            .listStyle(GroupedListStyle ())
            .navigationBarItems(
                leading:  Button ("Cancel") {
                    self.showingModal.toggle()
                },
                trailing: Button("Save") {
                }.disabled (disableSave))
        //}
    }
}

struct HostEditView_Previews: PreviewProvider {

    static var previews: some View {
        WrapperView ()
    }
    
    struct WrapperView: View {
        @State var host = Host ()

        var body: some View {
            HostEditView(host: $host, showingModal: .constant(true))
        }
    }
}
