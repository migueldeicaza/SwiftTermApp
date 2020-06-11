//
//  LazyView.swift
//  SwiftTermApp
//
// From: Chris Eidhof: https://gist.github.com/chriseidhof/d2fcafb53843df343fe07f3c0dac41d5
// Discussion: https://twitter.com/chriseidhof/status/1144242544680849410?lang=en

import Foundation
import SwiftUI

struct LazyView<Content: UIViewControllerRepresentable>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
