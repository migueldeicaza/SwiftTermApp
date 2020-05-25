//
//  SessionsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/28/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct SessionImage: View {
    var uiImage: UIImage
    var body: some View {
        Image (uiImage: uiImage)
            .resizable()
        .offset(x: 1, y: -116)
            .aspectRatio(contentMode: .fill)
            .frame(width: 320, height: 240, alignment: .center)
            .border(Color.black)
            .clipped()
    }
}

struct SessionView: View {
    var uiImage: UIImage
    var name: String
    var summary: String
    var live: TerminalViewController?
    
    var body: some View {
        
        VStack {
            #if false
            SessionImage (uiImage: uiImage)
                .brightness(0.1)
            //.padding(10)
                .background(Color.red)
            //.mask(RoundedRectangle(cornerRadius: 10))
            #else
            SwiftUITerminal(existing: live!)
                .frame(width: 320, height: 240, alignment: .center)
            
            #endif
            HStack {
                Image (systemName: "desktopcomputer")
                    .font (.system(size: 28))
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text (name)
                            .bold()
                            .foregroundColor(Color.white)
                        Spacer ()
                    }
                    Text (summary)
                        .brightness(0.6)
                        .font(.footnote)
                }
                Image (systemName: "xmark.circle.fill")
                    .foregroundColor(Color.black)
                    .brightness(0.6)
                    .font(.system(size: 30))
            }
        }.padding (10)
            .background(Color.black)
            .mask(RoundedRectangle(cornerRadius: 10))
            .padding ([.leading, .trailing], 16)
    }
}
struct ScreenOf: View {
    var tvc: TerminalViewController
    
    var body: some View {
        print ("running")
        return VStack {
            SessionView (uiImage: tvc.screenshot, name: tvc.host.alias, summary: tvc.host.summary(), live: tvc)
        }
    }
}

struct SessionsView: View {
    @ObservedObject var connections = Connections.shared

    var body: some View {
        Group {
            if connections.connections.count > 0 {
                ForEach (connections.connections.indices) { idx in
                    ScreenOf (tvc: self.connections.connections [idx])
                }
            } else {
                SessionView (uiImage: UIImage (contentsOfFile: "/tmp/shot.png")!,
                             name: "Linux Server", summary: "linux.azure.com", live: nil)
            }
            Spacer ()
        }.navigationBarTitle(Text("Sessions"))
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}
