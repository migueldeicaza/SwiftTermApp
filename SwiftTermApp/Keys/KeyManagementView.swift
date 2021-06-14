//
//  KeyManagementView.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct PasteKeyButton: View {
    @Binding var addKeyManuallyShown: Bool
    
    var body: some View {
        STButton (text: "Create", icon: "plus.circle")
            .onTapGesture {
                self.addKeyManuallyShown = true
        }
    }
}

struct KeyManagementView: View {
    @State var newKeyShown = false
    @State var addKeyManuallyShown = false
    @State var addFromFileShown = false
    @ObservedObject var store: DataStore = DataStore.shared
    @State private var editMode = EditMode.inactive

    var action: ((Key)-> ())? = nil
    
    func delete (at offsets: IndexSet)
    {
        store.keys.remove(atOffsets: offsets)
        store.saveState()
    }
    
    private func move(source: IndexSet, destination: Int)
    {
        store.keys.move (fromOffsets: source, toOffset: destination)
        store.saveState()
    }

    var body: some View {
        List {
            VStack {
                CreateLocalKeyButtons ()
                STButton (text: "Add Key", icon: "plus.circle")
                    .onTapGesture {
                        self.addKeyManuallyShown = true
                    }
                    .sheet (isPresented: self.$addKeyManuallyShown) {
                        AddKeyManually (addKeyManuallyShown: self.$addKeyManuallyShown)
                    }

                STButton (text: "Import Key from File", icon: "folder.badge.plus")
                    .onTapGesture {
                        self.addFromFileShown = true
                    }
                    .sheet (isPresented: self.$addFromFileShown, onDismiss: { self.addFromFileShown = false }) {
                        STFilePicker()
                    }
            }
            ForEach(store.keys.indices, id: \.self){ idx in
                KeyView (key: self.$store.keys [idx], action: self.action)
            }
            .onDelete(perform: delete)
            .onMove(perform: move)
            .environment(\.editMode, $editMode)
            .cornerRadius(10)
        }
        .listStyle(DefaultListStyle())
        .navigationTitle("Keys")
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                HStack {
                    Button (action: {
                        self.newKeyShown = true
                    }) {
                        Image (systemName: "plus")
                    }
                    EditButton()
                }
            }
        }
        .sheet(isPresented: self.$newKeyShown) {
            GenerateKey(showGenerator: self.$newKeyShown, generateKey: { a, b, c in nil } )
        }
    }
}

struct KeyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            //GenerateKey(showGenerator: .constant(true), generateKey: { a, b, c in "" })
            KeyManagementView()
        }
    }
}

