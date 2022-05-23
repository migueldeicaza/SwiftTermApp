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
        STButton (text: "Create", icon: "plus.circle") {
            self.addKeyManuallyShown = true
        }
    }
}


struct KeyManagementView: View {
    @EnvironmentObject var dataController: DataController
    private var keys: FetchRequest<CKey>
    @Environment(\.managedObjectContext) var moc
    @State var newKeyShown = false
    @State var addFromFileShown = false
    @State private var editMode = EditMode.inactive
    @State var action: ((Key)-> ())? = nil
    
    init (action: ((Key)->())? = nil) {
        _action = State (initialValue: action)
        keys = FetchRequest<CKey>(entity: CKey.entity(), sortDescriptors: [
            NSSortDescriptor(keyPath: \CKey.sName, ascending: true)
        ])
    }

    func delete (at offsets: IndexSet)
    {
        let keyItems = keys.wrappedValue
        for offset in offsets {
            dataController.delete(key: keyItems [offset])
        }

        dataController.save()
    }
    
    var body: some View {
        VStack {
            CreateLocalKeyButtons ()
            if keys.wrappedValue.count == 0 {
                HStack (alignment: .top){
                    Image (systemName: "key")
                        .font (.title)
                    Text ("Keys allow you to easily log into hosts without having to type in passwords.\n\n[Learn More...](https://github.com/migueldeicaza/SwiftTermApp/wiki/Keys)")
                        .font (.body)
                }.padding ()
                Spacer ()
            } else {
                List {
                    
    //                STButton (text: "Import Key from File", icon: "folder.badge.plus", centered: false)
    //                    .onTapGesture {
    //                        self.addFromFileShown = true
    //                    }
    //                    .sheet (isPresented: self.$addFromFileShown, onDismiss: { self.addFromFileShown = false }) {
    //                        STFilePicker()
    //                    }
                    ForEach(keys.wrappedValue, id: \.self) { key in
                        KeySummaryView (key: key, action: self.action)
                    }
                    .onDelete(perform: delete)
                    .environment(\.editMode, $editMode)
                    .cornerRadius(10)
                }.listStyle(DefaultListStyle())
            }
        }
        .navigationTitle("Keys")
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

struct KeyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            KeyManagementView()
        }
    }
}

