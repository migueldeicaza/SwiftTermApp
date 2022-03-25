//
//  SnippetBrowser.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/25/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct SnippetBrowser: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @State var activatedItem: Snippet? = nil
    
    func delete (at offsets: IndexSet) {
        store.snippets.remove(atOffsets: offsets)
        store.saveSnippets ()
    }
    
    private func move(source: IndexSet, destination: Int) {
        store.snippets.move(fromOffsets: source, toOffset: destination)
        store.saveSnippets ()
    }

    var body: some View {
        List {
            STButton (text: "Add Snippet", icon: "plus.circle")
                .onTapGesture {
                    self.activatedItem = Snippet(title: "", command: "", platforms: [])
                }
            Section {
                ForEach(self.store.snippets.indices, id: \.self) { idx in
                    SnippetSummary (snippet: store.snippets [idx])
                    .onTapGesture {
                        activatedItem = store.snippets [idx]
                    }
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }
        }
        .listStyle(.grouped)
        .navigationTitle(Text("Snippets"))
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                EditButton ()
            }
        }
        .sheet (item: $activatedItem) { item in
            SnippetEditor (snippet: item)
        }
    }
}


struct SnippetBrowser_Previews: PreviewProvider {
    static var previews: some View {
        SnippetBrowser()
    }
}
