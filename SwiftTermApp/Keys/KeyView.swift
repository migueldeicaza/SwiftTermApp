//
//  KeyView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/13/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct KeySummaryView: View {
    @Binding var key: Key
    @State var showEdit = false
    var action: ((Key)-> ())?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "lock")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24)
                .padding(8)
            VStack (alignment: .leading) {
                Text ("\(key.name)")
                    .font(.body)
                Text ("Key Type: \(key.type)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }.onTapGesture {
            if let a = self.action {
                a (self.key)
            } else {
                self.showEdit = true
            }
        }.sheet(isPresented: $showEdit) {
            EditKey(addKeyManuallyShown: self.$showEdit, key: self.$key)
        }
    }
}

struct KeyView: View {
    @Binding var key: Key
    @State var showEdit = false
    var action: ((Key)-> ())?

    func shareKeyAction () {
        let activity = UIActivityViewController(activityItems: [key.publicKey], applicationActivities: nil)
        
        if let mainWindow = UIApplication.shared.windows.filter  {$0.isKeyWindow}.first {
            mainWindow.rootViewController?.present(activity, animated: true, completion: nil)
        }
    }
    
    var body: some View {
        List {
            Section {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "lock")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24)
                        .padding(8)
                    VStack (alignment: .leading) {
                        Text ("\(key.name)")
                            .font(.body)
                        Text ("Key Type: \(key.type)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }.onTapGesture {
                    if let a = self.action {
                        a (self.key)
                    } else {
                        self.showEdit = true
                    }
                }.sheet(isPresented: $showEdit) {
                    EditKey(addKeyManuallyShown: self.$showEdit, key: self.$key)
                }
            }
            Section {
                HStack {
                    Button (action: shareKeyAction, label: {
                        HStack {
                            Image (systemName: "square.and.arrow.up")
                            Text ("Share Public Key")
                        }
                    })
                }
            }
        }
    }
}

struct KeyView_Previews: PreviewProvider {
    @State static var key = sampleKey
    static var previews: some View {
        KeyView(key: $key)
    }
}
