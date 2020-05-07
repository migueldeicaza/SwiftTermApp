//
//  AddKeyFromFile.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/4/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

final class FilePicker: NSObject, UIViewControllerRepresentable, UIDocumentPickerDelegate {
    typealias UIViewControllerType = UIDocumentPickerViewController
    var callback: ([URL]) -> ()
    
    public init (callback: @escaping ([URL]) -> ())
    {
        self.callback = callback
    }
    
    lazy var viewController : UIDocumentPickerViewController = {
        let vc = UIDocumentPickerViewController (documentTypes: ["public.data"], in: .open)
        vc.allowsMultipleSelection = false
        vc.shouldShowFileExtensions = true
        return vc
    }()
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<FilePicker>) -> UIDocumentPickerViewController {
        viewController.delegate = self
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<FilePicker>) {
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true) {}
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        callback (urls)
    }
}

struct STFilePicker: View {
    func saveKey (urls: [URL])
    {
        guard let url = urls.first else {
            return
        }
        if let privKey = try? String (contentsOf: url) {
            let k = Key(id: UUID(),type: "TODO: guess the key type", name: url.lastPathComponent, privateKey: privKey, publicKey: "", passphrase: "")
            DataStore.shared.save(key: k)
        }
    }
    var body: some View {
        FilePicker (callback: saveKey)
    }
}

///
/// A button that shows a file icon, and when selected, inserts the contents
/// of the file into the target field
///
struct ContentsFromFile: View {
    @Binding var target: String
    @State var pickerShown = false
    
    func setTarget (urls: [URL])
    {
        guard let url = urls.first else {
            return
        }
        if let contents = try? String (contentsOf: url) {
            target = contents
        }
        pickerShown = false
    }
    
    var body: some View {
        Image (systemName: "folder")
            .foregroundColor(ButtonColors.highColor)
            .font(Font.headline.weight(.light))
            .onTapGesture { self.pickerShown = true }
            .sheet(isPresented: self.$pickerShown) {
                FilePicker (callback: self.setTarget)
            }
    }
}

struct STFilePicker_Previews: PreviewProvider {
    static var previews: some View {
        ContentsFromFile (target: .constant (""))
    }
}
