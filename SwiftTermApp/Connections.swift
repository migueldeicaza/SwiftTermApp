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

class Connection: Codable, Identifiable {
    var host: Host
    var id = UUID ()
    //var terminal: UIView
    
    init ()
    {
        host = Host()
    }
    
    required init (from: Decoder)
    {
        host = Host()
    }
    
    func encode (to: Encoder)
    {
        
    }
}

class Connections: ObservableObject {
    @Published var connections: [Connection] = [
    ]
    
    static var shared: Connection = Connection()
}
