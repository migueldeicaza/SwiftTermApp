//
//  LocalNetworkView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/6/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Network
class LocalComputers: ObservableObject {
    @Published public var computers: [NWEndpoint] = [
    ]
    
    var browser: NWBrowser
    
    init ()
    {
        let pars = NWParameters ()
        pars.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_ssh._tcp", domain: "local."), using: pars)
        browser.browseResultsChangedHandler = { res, change in
            for item in change {
                switch item {
                case .identical:
                    break
                case .added(let new):
                    self.computers.append(new.endpoint)
                case .removed(let old):
                    for x in 0..<self.computers.count {
                        if self.computers [x].debugDescription == old.endpoint.debugDescription {
                            self.computers.remove(at: x)
                            break
                        }
                    }
                case .changed(old: let old, new: let new, flags: let flags):
                    print ("oops")
                @unknown default:
                    break
                }
            }
        }
        browser.start(queue: .main)
    }
    
    static var shared = LocalComputers()
}

struct LocalHostView: View {
    var host: NWEndpoint
    @State var showingModal = false
    
    func title () -> String {
        switch host {
        
        case .hostPort(host: let host, port: let port):
            return "\(host)"
        case .service(name: let name, type: let type, domain: let domain, interface: let interface):
            return "\(name) \(type)"
        case .unix(path: let path):
            return "Unix?"
        case .url(_):
            return "Url?"
        @unknown default:
            return "Unknown?"
        }
    }

    func subTitle () -> String {
        switch host {
        
        case .hostPort(host: let host, port: let port):
            return "\(host) \(port)"
        case .service(name: let name, type: let type, domain: let domain, interface: let interface):
            return "service \(name) type=\(type) on \(domain)"
        case .unix(path: let path):
            return "Unix?"
        case .url(_):
            return "Url?"
        @unknown default:
            return "Unknown?"
        }
    }

    var body: some View {
        NavigationLink (destination: Text ("Host")) {
            HStack (spacing: 12){
                getDefaultImage()
                    .font (.system(size: 28))
                    .brightness( 0.6)
                    .colorMultiply(Color.black)
                VStack (alignment: .leading, spacing: 4) {
                    HStack {
                        Text (title())
                            .bold()
                        Spacer ()
                    }
                    Text (subTitle())
                        .brightness(0.4)
                        .font(.footnote)
                }
                .onTapGesture {
                    self.showingModal = true
                }
            }.sheet(isPresented: $showingModal) {
                //HostEditView(host: self.host, showingModal: self.$showingModal)
            }
            .contextMenu {
                NavigationLink(destination: Text ("Hello") /* SwiftUITerminal(host: self.host, createNew: true, interactive: true) */){
                    Text("New Connection")
                    Image(systemName: "plus.circle")
                }

                Button(action: {
                    print ("wussup")
                }) {
                    Text("Close Connection")
                    Image(systemName: "minus.circle")
                }
            }
        }
    }
}

struct LocalNetworkView: View {
    @ObservedObject var shared = LocalComputers.shared
    
    var body: some View {
        VStack {
            Text ("Hello")
            ForEach (shared.computers, id: \.self) { nwe in
                LocalHostView (host: nwe)
            }
        }
    }
}

struct LocalNetworkView_Previews: PreviewProvider {
    static var previews: some View {
        LocalNetworkView()
    }
}
