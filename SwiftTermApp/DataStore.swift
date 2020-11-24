//
//  DataStore.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import Combine

class Key: Codable, Identifiable {
    var id: UUID
    var type: String = ""
    var name: String = ""
    var privateKey: String = ""
    var publicKey: String = ""
    var passphrase: String = ""
    
    public init (id: UUID, type: String = "", name: String = "", privateKey: String = "", publicKey: String = "", passphrase: String = "")
    {
        self.id = id
        self.type = type
        self.name = name
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.passphrase = passphrase
    }
}

struct Host: Codable, Identifiable {
    var id = UUID()
    var alias: String = ""
    var hostname: String = ""
    var backspaceAsControlH: Bool = false
    var port: Int = 22
    var usePassword: Bool = true
    var username: String = ""
    var password: String = ""
    var hostKindGuess: String = ""
    var environmentVariables: [String] = []
    var startupScripts: [String] = []
    
    // This is the UUID of the key registered with the app
    var sshKey: UUID?
    var style: String = ""
    var background: String = ""
    var lastUsed: Date = Date.distantPast
    
    func summary() -> String {
        hostname + (style != "" ? ", \(style)" : "")
    }
}

class DataStore: ObservableObject {
    static let testKey1 = Key (id: UUID(), type: "RSA/1024", name: "Fake Legacy Key", privateKey: "", publicKey: "", passphrase: "")
    static let testKey2 = Key (id: UUID(), type: "RSA/4098", name: "Fake 2020 iPhone Key", privateKey: "", publicKey: "", passphrase: "")
    
    static let testUuid2 = UUID ()
    
    var defaults: UserDefaults?
    
    @Published var hosts: [Host] = [
       Host(alias: "Dummy MacPro",         hostname: "192.168.86.74", lastUsed: Date ()),
       //Host(alias: "Dummy Raspberri Pi",   hostname: "raspberry.tirania.org", lastUsed: Date ()),
       //Host(alias: "Dummy MacBook",        hostname: "road.tirania.org", usePassword: false, sshKey: DataStore.testKey1.id),
       //Host(alias: "Dummy Old Vax",        hostname: "oldvax.tirania.org",usePassword: false, sshKey: DataStore.testKey2.id),
       //Host(alias: "Dummy Old DECStation", hostname: "decstation.tirania.org"),
    ]
    
    @Published var keys: [Key] = [
        testKey1, testKey2
    ]
    
    let hostsArrayKey = "hostsArray"
    let keysArrayKey = "keysArray"
    
    init ()
    {
        defaults = UserDefaults (suiteName: "SwiftTermApp")
        let decoder = JSONDecoder ()
        if let d = defaults {
            if let data = d.data(forKey: hostsArrayKey) {
                if let h = try? decoder.decode ([Host].self, from: data) {
                    hosts = h
                }
            }
            if let data = d.data(forKey: keysArrayKey) {
                if let k = try? decoder.decode ([Key].self, from: data) {
                    keys = k
                }
            }
        }
    }
    
    // Saves the data store
    func saveState ()
    {
        guard let d = defaults else {
            return
        }
        let coder = JSONEncoder ()
        if let hostData = try? coder.encode(hosts) {
            d.set (hostData, forKey: hostsArrayKey)
        }
        if let keyData = try? coder.encode (keys) {
            d.set (keyData, forKey: keysArrayKey)
        }
    }
    
    // Records the new host in the data store
    func save (host: Host)
    {
        if let idx = hosts.firstIndex (where: { $0.alias == host.alias }) {
            hosts.remove(at: idx)
            hosts.insert(host, at: idx)
        } else {
            hosts.append(host)
        }
        saveState ()
    }

    func used (host: Host)
    {
        if let f = hosts.firstIndex(where: {$0.id == host.id}){
            hosts [f].lastUsed = Date()
            saveState()
        }
    }
    // Records the new host in the data store
    func save (key: Key)
    {
        keys.append(key)
        saveState ()
    }

    func hasHost (withAlias: String) -> Bool
    {
        hosts.contains { $0.alias == withAlias }
    }
    
    func hostHasValidKey (host: Host) -> Bool {
        
        let c = keys.contains { $0.id == host.sshKey }
        return c
    }

    func updateGuess (for target: Host, to guess: String)
    {
        for i in 0..<hosts.count {
            if hosts [i].id == target.id {
                hosts [i].hostKindGuess = guess
            }
        }
    }

    // This for now returns the name, but if it is ambiguous, it could return a hash or something else
    func getSshDisplayName (forHost: Host) -> String {
        if let k = keys.first(where: { $0.id == forHost.sshKey }) {
            return k.name
        }
        return "none"
    }
    
    // Returns the most recent 3 values
    func recentIndices () -> [Int]
    {
        var res: [Int] = []
        let sorted = hosts.sorted(by: {a, b in a.lastUsed > b.lastUsed })
        for x in sorted.prefix(3) {
            if let idx = hosts.firstIndex(where: {$0.id == x.id }) {
                res.append(idx)
            }
        }
        return res
    }
    static var shared: DataStore = DataStore()
}
