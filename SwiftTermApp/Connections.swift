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
 
///
/// Tracks both the active sessions, as well as terminal views.
///
/// Note: terminal views are typically created first, and tracked before a session is created, which only takes place later
class Connections: ObservableObject {
    public static var shared: Connections = Connections()
    
    @Published public var sessions: [Session] = [
    ]

    @Published public var terminals: [SshTerminalView] = [
    ]
    
    public func active () -> Bool {
        return sessions.count > 0
    }
    
    public static func allocateConnectionId (avoidIds: [Int]) -> Int {
        var serials = Set<Int> ()
        
        for conn in shared.terminals {
            serials.update(with: conn.serial)
        }
        for usedId in avoidIds {
            serials.update(with: usedId)
        }
        for x in 0..<Int.max {
            if !serials.contains(x) {
                return x
            }
        }
        return -1
    }
    
    public static func remove (terminal: SshTerminalView)
    {
        if let idx = shared.terminals.firstIndex(of: terminal) {
            shared.terminals.remove (at: idx)
        }
        // This is used to track whether we should keep the display on, only when we have active terminals
        settings.updateKeepOn()
    }
        
    /// Tracks the terminal
    public static func track (terminal: SshTerminalView)
    {
        if shared.terminals.contains(terminal) {
            return
        }
        shared.terminals.append(terminal)
    }
    
    /// Tracks the terminal
    public static func track (session: Session)
    {
        if shared.sessions.contains(session) {
            return
        }
        shared.sessions.append(session)
        
        // This is used to track whether we should keep the display on, only when we have active terminals
        settings.updateKeepOn()
    }
    
    public static func lookupActive (host: Host) -> SshTerminalView?
    {
        return shared.terminals.first { $0.host.id == host.id }
    }
    
//    struct ConnectionState: Encodable, Decodable {
//        var hostId: UUID
//        var reconnectType: String
//        
//        // The serial associated with the host that we are saving
//        var serial: Int
//    }
//    
//    // Saves all the connections that could be restored
//    public static func saveState () {
//        guard let d = DataStore.shared.defaults else {
//            return
//        }
//        var state: [ConnectionState] = []
//        for x in shared.connections {
//            guard x.host.reconnectType != "" else { continue }
//            state.append (ConnectionState (hostId: x.host.id, reconnectType: x.host.reconnectType, serial: x.serial))
//        }
//        guard state.count > 0 else { return }
//        let coder = JSONEncoder ()
//        if let encoded = try? coder.encode(state) {
//            d.set (encoded, forKey: DataStore.shared.connectionsArrayKey)
//        }
//        d.synchronize()
//    }
//    
//    public static func getRestorableConnections () -> [ConnectionState] {
//        guard let d = DataStore.shared.defaults else {
//            return []
//        }
//        let decoder = JSONDecoder ()
//        
//        if let data = d.data(forKey: DataStore.shared.connectionsArrayKey) {
//            if let h = try? decoder.decode ([ConnectionState].self, from: data) {
//                return h
//            }
//        }
//        return []
//    }
}

