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

//
// This currently uses the .show(.primary), and .show(.secondary) to force the splitviewcontroller to act
// but it could be changed to instead set the preferredSplitBehavior and preferredDisplayMode, although
// this should likely be then changed if a terminal shows up, so that it can be hidden
struct UIKitShowSidebar: UIViewRepresentable {
    let activate: Bool
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
        if !activate { return uiView }
        if self.showSidebar {
            DispatchQueue.main.async { [weak uiView] in
                if let target = uiView?.next {
                    let r = nextResponder (target: target, of: UISplitViewController.self)
                    if let s = r {
                        print (s.preferredDisplayMode)
                    }
                    r?.show(.primary)
                }
            }
        } else {
            DispatchQueue.main.async { [weak uiView] in
                if let target = uiView?.next {
                    let r = nextResponder (target: target, of: UISplitViewController.self)
                    if let s = r {
                        print (s.preferredDisplayMode)
                    }
                    //r?.preferredSplitBehavior = .tile
                    //r?.preferredDisplayMode = .oneOverSecondary
                    r?.show(.secondary)
                }
            }
        }
        return uiView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if !activate { return }
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
        #if DEBUG
        Text ("DEBUG: Using NothingView to force SplitViewController mode")
            .bold()
        #endif
        UIKitShowSidebar(activate: UIDevice.current.userInterfaceIdiom == .pad, showSidebar: showSidebar)
            .frame(width: 0,height: 0)
            .onAppear {
                showSidebar = true
            }
            .onDisappear {
                showSidebar = false
            }
    }
}
