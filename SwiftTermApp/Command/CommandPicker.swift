//
//  CommandPicker.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/25/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct CommandPicker: View {
    @EnvironmentObject var dataController: DataController
    private var snippets: FetchRequest<CUserSnippet>
    @Environment(\.managedObjectContext) var moc
    @Environment(\.dismiss) private var dismiss
    @State var terminalGetter: ()->AppTerminalView?
    @State private var searchText = ""

    init (terminalGetter: @escaping ()->AppTerminalView?) {
        snippets = FetchRequest<CUserSnippet>(entity: CUserSnippet.entity(), sortDescriptors: [
            NSSortDescriptor(keyPath: \CUserSnippet.title, ascending: true)
        ])
        self._terminalGetter = State (initialValue: terminalGetter)
    }

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
    
    var searchResults: [CUserSnippet] {
        if searchText.isEmpty {
            return snippets.wrappedValue.map { $0 }
        } else {
            return snippets.wrappedValue.filter { snippet in
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
