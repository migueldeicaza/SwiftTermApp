//
//  SplitViewCustomization.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/31/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

struct UIKitShowSidebar: UIViewRepresentable {
  let showSidebar: Bool
  
    func nextResponder<T> (target: UIResponder, of type: T.Type) -> T? {
        guard let nextValue = target.next  else {
            return nil
        }
        guard let result = nextValue as? T else {
            return nextResponder(target: nextValue, of: type.self)
        }
        return result
    }
    
    func makeUIView(context: Context) -> some UIView {
        let uiView = UIView()
        if self.showSidebar {
            DispatchQueue.main.async { [weak uiView] in
                if let target = uiView?.next {
                    nextResponder (target: target, of: UISplitViewController.self)?
                        .show(.primary)
                }
            }
        } else {
            DispatchQueue.main.async { [weak uiView] in
                if let target = uiView?.next {
                    nextResponder (target: target, of: UISplitViewController.self)?
                        .show(.secondary)
                }
            }
        }
        return uiView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        DispatchQueue.main.async { [weak uiView] in
            if let target = uiView?.next {
                nextResponder(target: target, of: UISplitViewController.self)?
                    .show(showSidebar ? .primary : .secondary)
            }
        }
    }
}

struct NothingView: View {
    @State var showSidebar: Bool = false
    var body: some View {
        Text("Nothing to see")
        if UIDevice.current.userInterfaceIdiom == .pad {
            UIKitShowSidebar(showSidebar: showSidebar)
                .frame(width: 0,height: 0)
                .onAppear {
                    showSidebar = true
                }
                .onDisappear {
                    showSidebar = false
                }
        }
    }
}
