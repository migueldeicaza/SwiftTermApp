//
//  SnippetEditor.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/25/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct SnippetEditor: View {
    @State var snippet: Snippet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack (alignment: .leading) {
                        Text ("Title:")
                        TextField ("name", text: $snippet.title)
                    }
                }
                Section {
                    Text ("Command")
                    TextEditor (text: $snippet.command)
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
                        if let existing = DataStore.shared.snippets.firstIndex(where: { $0.id == snippet.id}) {
                            DataStore.shared.snippets.remove(at: existing)
                            DataStore.shared.snippets.insert(contentsOf: [snippet], at: existing)
                        } else {
                            DataStore.shared.snippets.append (snippet)
                        }
                        DataStore.shared.saveSnippets()
                        dismiss ()
                    }
                }
            }
            
        }
    }
}

struct SnippetEditor_Previews: PreviewProvider {
    static var previews: some View {
        SnippetEditor(snippet: Snippet (title: "List processes", command: "ps auxww\nasdfa\nasdfasdfa\nasdfasdfasdf\nasdfasdfasdf\nasdf\nanother\nand one more", platforms: ["linux", "apple"]))
    }
}
