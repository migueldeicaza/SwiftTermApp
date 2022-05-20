//
//  DataModelTypes.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/19/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

protocol Host {
    /// Unique ID, used both inside Swift to differentiate structures and for tracking our records and keys
    var id: UUID { get set }

    /// Public name for this host
    var alias: String { get set }

    /// Address to connect to
    var hostname: String { get set }

    /// Setting for this host, should the backspace key send a control-h
    var backspaceAsControlH: Bool { get set }

    /// The port to which we will connect in the host
    var port: Int { get set }

    /// If true, this host uses a password, rather than a key
    var usePassword: Bool { get set }

    /// Username to login as
    var username: String { get set }

    /// If usePassword is set, this might contain the password to provide for authentication
    var password: String { get set }

    /// The guessed host type - this is used to pick the icon for the host, and it is sometimes automatically guessed and set
    var hostKind: String { get set }

    /// Environment variables to pass on the connection
    var environmentVariables: [String:String] { get set }

    /// Scripts to execute on startup
    var startupScripts: [String] { get set }

    /// This is the UUID of the key registered with the app
    var sshKey: UUID? { get set }

    /// The current color theme style name, if the style is "" it means "use the default"
    var style: String { get set }

    /// The values are `default` to pick the value from settings, "" to use a solid color, or the name of a live background
    var background: String { get set }

    /// Last time this host was used, to show the sorted list of hosts used
    var lastUsed: Date { get set }

    /// Reconnection type, one of "" or "tmux"
    var reconnectType: String { get set }
}

extension Host {
    func summary() -> String {
        hostname + (style != "" ? ", \(style)" : "")
    }
}

class MemoryHost: Host {
    internal init(id: UUID = UUID(), alias: String = "", hostname: String = "", backspaceAsControlH: Bool = false, port: Int = 22, usePassword: Bool = true, username: String = "", password: String = "", hostKind: String = "", environmentVariables: [String:String] = [:], startupScripts: [String] = [], sshKey: UUID? = nil, style: String = "", background: String = "", lastUsed: Date = Date.distantPast) {
        self.id = id
        self.alias = alias
        self.hostname = hostname
        self.backspaceAsControlH = backspaceAsControlH
        self.port = port
        self.usePassword = usePassword
        self.username = username
        self.password = password
        self.hostKind = hostKind
        self.environmentVariables = environmentVariables
        self.startupScripts = startupScripts
        self.sshKey = sshKey
        self.style = style
        self.background = background
        self.lastUsed = lastUsed
    }
    
    var id = UUID()
    var alias: String = ""
    var hostname: String = ""
    var backspaceAsControlH: Bool = false
    var port: Int = 22
    var usePassword: Bool = true
    var username: String = ""
    var password: String = ""
    var hostKind: String = ""
    var environmentVariables: [String:String] = [:]
    var startupScripts: [String] = []
    var sshKey: UUID?
    var style: String = ""
    var background: String = ""
    var lastUsed: Date = Date.distantPast
    var reconnectType: String = ""
}
