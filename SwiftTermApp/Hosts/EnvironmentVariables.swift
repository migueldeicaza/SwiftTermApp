//
//  EnvironmentVariables.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/23/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct EnvSelection: Identifiable {
    var name: String
    var value: String
    var id: String { return name }
}

struct EnvironmentVariables: View {
    @Binding var variables: [String:String]
    @State var activatedItem: EnvSelection? = nil
    
    func delete (at offsets: IndexSet) {
        abort()
    }
    private func move(source: IndexSet, destination: Int) {
        abort()
    }

    var body: some View {
        List {
            STButton (text: "Add Variable", icon: "plus.circle")
                .onTapGesture {
                    activatedItem = EnvSelection (name: "", value: "")
                }

            Section {
                ForEach(variables.sorted(by: >), id: \.key) { key, value in
                    
                    VStack (alignment: .leading){
                        Text ("\(key)")
                            .font (.system (.headline, design: .monospaced))
                        Text ("\(value)").font(.body)
                            .font (.system (.body, design: .monospaced))
                            .lineLimit(1)
                            .foregroundColor(.gray)
                    }.onTapGesture {
                        activatedItem = EnvSelection (name: key, value: value)
                    }
                }
                .onDelete(perform: delete)
            }
            Section {
                Text ("While it is possible to configure environment variables, some servers disable setting environment variables.   Check your `sshd_config` file on your server for the *PermitUserEnvironment* setting")
            }
        }
        .listStyle(.grouped)
        .navigationTitle(Text("Environment Variables"))
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                EditButton ()
            }
        }
        .sheet (item: $activatedItem) { item in
            EnvironmentVariableEdit(variables: $variables,
                                    variable: item,
                                    newVariable: item.name == "")
        }
    }
}

struct EnvironmentVariables_Previews: PreviewProvider {
    @State static var variables = ["PATH":"/Library/Apple/usr/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/cvs/fuchsia/fuchsia/.jiri_root/bin", "SHELL":"bash" ]
    
    static var previews: some View {
        EnvironmentVariables(variables: $variables)
    }
}
