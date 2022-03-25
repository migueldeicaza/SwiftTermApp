//
//  CommandPicker.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/25/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct CommandPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = DataStore.shared
    @State var terminalGetter: ()->AppTerminalView?
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(searchResults, id: \.id) { snippet in
                SnippetSummary(snippet: snippet)
                    .onTapGesture {
                        guard let terminal = terminalGetter () else {
                            return
                        }
                        dismiss()
                        terminal.send(txt: snippet.command)
                    }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem (placement: .navigationBarLeading) {
                Button ("Dismiss") {
                    dismiss()
                }
            }
        }
    }
    
    var searchResults: [Snippet] {
        if searchText.isEmpty {
            return store.snippets
        } else {
            return store.snippets.filter { snippet in
                snippet.title.localizedCaseInsensitiveContains(searchText) || snippet.command.localizedCaseInsensitiveContains (searchText)
            }
        }
    }
}

struct CommandPicker_Previews: PreviewProvider {
    static var previews: some View {
        CommandPicker { return nil }
    }
}
