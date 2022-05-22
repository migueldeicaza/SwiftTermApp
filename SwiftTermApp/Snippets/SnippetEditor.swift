//
//  SnippetEditor.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/25/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct SnippetEditor: View {
    @EnvironmentObject var dataController: DataController
    @State var snippet: CUserSnippet?
    @State var title: String = ""
    @State var command: String = ""
    @State var platforms: [String] = []
    @Environment(\.dismiss) private var dismiss

    init (snippet: CUserSnippet?) {
        self._snippet = State (initialValue: snippet)

        if let snippet = snippet {
            _title = State (initialValue: snippet.title)
            _command = State (initialValue: snippet.command)
            _platforms = State (initialValue: snippet.platforms)
        }
    }

    func saveAndLeave () {
        let snippet: CUserSnippet
        if let existingSnippet = self.snippet {
            snippet = existingSnippet
        } else {
            snippet = CUserSnippet (context: dataController.container.viewContext)
        }
        dismiss()
        snippet.objectWillChange.send ()
        snippet.platforms = platforms
        snippet.command = command
        snippet.title = title
        dataController.save()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack (alignment: .leading) {
                        Text ("Title:")
                        TextField ("name", text: $title)
                    }
                }
                Section {
                    Text ("Command")
                    TextEditor (text: $command)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                        .font (.system (.body, design: .monospaced))
                        .frame(minHeight: 80)
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
                        self.saveAndLeave ()
                    }
                }
            }
            
        }
    }
}

struct SnippetEditor_Previews: PreviewProvider {
    static var previews: some View {
        SnippetEditor(snippet: DataController.preview.createSampleSnippet ())
    }
}
