//
//  UIViewController+SwiftUI.swift
//  SwiftTermApp
//
// From Timothy Costa
//
// https://gist.github.com/timothycosta/a43dfe25f1d8a37c71341a1ebaf82213
// https://stackoverflow.com/questions/56756318/swiftui-presentationbutton-with-modal-that-is-full-screen
//

import Foundation
import UIKit
import SwiftUI

//struct ViewControllerHolder {
//    weak var value: UIViewController?
//    init(_ value: UIViewController?) {
//        self.value = value
//    }
//}
//
//struct ViewControllerKey: EnvironmentKey {
//    static var defaultValue: ViewControllerHolder { return ViewControllerHolder(UIApplication.shared.windows.first?.rootViewController ) }
//}
//
//extension EnvironmentValues {
//    var viewController: ViewControllerHolder {
//        get { return self[ViewControllerKey.self] }
//        set { self[ViewControllerKey.self] = newValue }
//    }
//}
//
//extension UIViewController {
//    func present<Content: View>(presentationStyle: UIModalPresentationStyle = .automatic, transitionStyle: UIModalTransitionStyle = .coverVertical, animated: Bool = true, completion: @escaping () -> Void = {}, @ViewBuilder builder: () -> Content) {
//        let toPresent = UIHostingController(rootView: AnyView(EmptyView()))
//        toPresent.modalPresentationStyle = presentationStyle
//        toPresent.rootView = AnyView(
//            builder()
//                .environment(\.viewController, ViewControllerHolder(toPresent))
//        )
//        if presentationStyle == .overCurrentContext {
//            toPresent.view.backgroundColor = .clear
//        }
//        self.present(toPresent, animated: animated, completion: completion)
//    }
//}
