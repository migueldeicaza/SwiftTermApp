//
//  Connections.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/28/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import Combine
import UIKit
import SwiftTerm

class Connections: ObservableObject {
    @Published public var connections: [SshTerminalView] = [
    ]
    
    public func active () -> Bool {
        return connections.count > 0
    }
    public static var shared: Connections = Connections()
    
    // Tracks the connection.
    public static func track (connection: SshTerminalView)
    {
        if shared.connections.contains(connection) {
            return
        }
        shared.connections.append(connection)
    }
    
    public static func lookupActive (host: Host) -> SshTerminalView?
    {
        return shared.connections.first { $0.host.id == host.id }
    }
}
