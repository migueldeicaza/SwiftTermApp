//
//  KeyView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/13/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import UIKit

struct ShareKeyView: UIViewControllerRepresentable {
    @Binding var publicKey: String
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareKeyView>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [publicKey],
            applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareKeyView>) {
    }
}

struct KeySummaryView: View {
    @Binding var key: Key
    @State var showEdit = false
    @State var showSharing = false
    var action: ((Key)-> ())?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack (alignment: .top) {
                Image(systemName: "key")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame (height: 20)
                    .padding(8)
                    
                VStack (alignment: .leading) {
                    Text ("\(key.name)")
                        .font(.body)
                    Text ("Key Type: \(key.type.description)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer ()
            }
            .onTapGesture {
                if let a = self.action {
                    a (self.key)
                } else {
                    self.showEdit = true
                }
            }.sheet(isPresented: $showEdit) {
                EditKey(addKeyManuallyShown: self.$showEdit, key: self.key, disableChangePassword: true)
            }.sheet(isPresented: $showSharing) {
                ShareKeyView(publicKey: $key.publicKey)
            }
            Button (action: { showSharing.toggle () }) {
                Image(systemName: "square.and.arrow.up")
                    //.resizable()
                    //.aspectRatio(contentMode: .fit)
                    .foregroundColor(.blue)
            }
        }
    }
}


struct KeyView_Previews: PreviewProvider {
    @State static var key = sampleKey
    static var previews: some View {
        KeySummaryView(key: $key)
    }
}
