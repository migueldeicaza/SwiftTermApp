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
            List {
                Section {
                    HStack {
                        Text ("Alias").modifier(PrimaryLabel())
                        TextField("name", text: self.$host.alias)

                    }
                    HStack {
                        Text ("Host").modifier(PrimaryLabel())
                        TextField ("Required", text: self.$host.hostname)
                    }
                    HStack {
                        Text ("Port").modifier(PrimaryLabel())
                        TextField ("22", value: self.$host.port, formatter: NumberFormatter ())
                            .keyboardType(.numberPad)
                        
                    }
                }

                Section (header: Text ("Identity")) {
                    HStack {
                        Text ("User").modifier(PrimaryLabel())
                        TextField ("username", text: self.$host.username)
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
                    HStack {
                        Text ("Password").modifier(PrimaryLabel())
                        TextField ("password, or leave empty to use a key", text: self.$host.username)
                    }
                    HStack {
                        Text ("SSH Key").modifier(PrimaryLabel())
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
