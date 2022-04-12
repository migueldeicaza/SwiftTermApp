//
//  EnvironmentVariableEdit.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/24/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct EnvironmentVariableEdit: View {
    @Binding var variables: [String:String]
    @Environment(\.dismiss) private var dismiss

    @State var variable: EnvSelection
    @State var newVariable: Bool

    // If it is a new variable, do not allow overriding an existing value
    var disableSave: Bool {
        get {
            (newVariable && variables.keys.contains(variable.name)) || variable.name == ""
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack (alignment: .leading) {
                        HStack {
                            Text ("Variable")
                            Spacer ()
                            if disableSave {
                                Button {
                                    print("Edit button was tapped")
                                } label: {
                                    if variable.name != ""  {
                                        Text("Name Conflict")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        TextField ("name", text: $variable.name)
                            .font (.system (.body, design: .monospaced))
                            .disabled(variable.name != "")
                            .foregroundColor(newVariable ? .primary : .secondary)
                        padding()
                        Text ("Value")
                        TextField ("value", text: $variable.value)
                            .lineLimit(3)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .font (.system (.body, design: .monospaced))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem (placement: .navigationBarLeading) {
                    Button ("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Because we are delaying the hiding of the window,
                        // disable the check below, as we are already proceeding
                        // and this hides an ugly artifact for half a second, showing
                        // that the variable is clashing when it is indeed, not clashing.
                        variables [variable.name] = variable.value
                        
                        dismiss ()
                    }.disabled (disableSave)
                }
            }
            
        }
    }
}

struct EnvironmentVariableEdit_Previews: PreviewProvider {
    @State static var variables = ["PATH":"/Library/Apple/usr/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/cvs/fuchsia/fuchsia/.jiri_root/bin", "SHELL":"bash" ]
    @State static var showVariableEdit = false
    
    static var previews: some View {
        VStack {
            EnvironmentVariableEdit(variables: $variables, variable: EnvSelection(name: "MYPATH", value: "/usr/local"), newVariable:  true)
        }
    }
}
