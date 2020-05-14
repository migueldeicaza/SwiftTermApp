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

class Connections: ObservableObject {
    @Published public var connections: [TerminalViewController] = [
    ]
    
    public static var shared: Connections = Connections()
    
    public static func add (connection: TerminalViewController)
    {
        shared.connections.append(connection)
    }
    
    public static func lookupActive (host: Host) -> TerminalViewController?
    {
        return shared.connections.first { $0.host.id == host.id }
    }
}
