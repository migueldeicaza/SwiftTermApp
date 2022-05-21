//
//  DataStore.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import Combine

class Snippet: Codable, Identifiable {
    var title: String
    var command: String
    var platforms: [String]
    var id: UUID
    
    public init (title: String, command: String, platforms: [String]) {
        self.id = UUID()
        self.title = title
        self.command = command
        self.platforms = platforms
    }
}

/// Represents a host we have connected to
struct KnownHost: Identifiable {
    var host: String
    var keyType: String
    var key: String
    var rest: String
    var id: UUID
}

class DataStore: ObservableObject {
    static let testKey1 = MemoryKey (id: UUID(), type: .rsa (1024), name: "Fake Legacy Key", privateKey: "", publicKey: "", passphrase: "")
    static let testKey2 = MemoryKey (id: UUID(), type: .rsa (4096), name: "Fake 2020 iPhone Key", privateKey: "", publicKey: "", passphrase: "")
    
    static let testUuid2 = UUID ()
    
    var defaults: UserDefaults?
    
    @Published var snippets: [Snippet] = [
    ]
    @Published var knownHosts: [KnownHost] = []
    
    /// Event raised when the properties that can be changed on a live connection have changed
    var runtimeVisibleChanges = PassthroughSubject<Host,Never> ()
    
    let hostsArrayKey = "hostsArray"
    let keysArrayKey = "keysArray2"
    let snippetArrayKey = "snippetArray"
    let connectionsArrayKey = "connectionsArray"
    public var knownHostsPath: String
    
    init ()
    {
        func getKnownHostsPath () -> String {
            let fm = FileManager.default
            guard let p = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                return "known_hosts"
            }
            try? fm.createDirectory (at: p, withIntermediateDirectories: true, attributes: nil)
            return p.path + "/known_hosts"
        }
        self.knownHostsPath = getKnownHostsPath()
        
        #if DEBUG
        let loadDebug = FileManager.default.fileExists(atPath: "/tmp/swiftterm-debug.hosts")
        #else
        let loadDebug = false
        #endif
        
        if loadDebug {
#if DEBUG
            loadDataStoreFromDebug ()
#endif
        } else {
            loadDataStoreFromDefaults ()
        }
        updateHostMap ()
        loadKnownHosts()
    }

    func updateHostMap () {
        idToHost = [:]
//        for host in hosts {
//            idToHost [host.id] = host
//        }
    }
    
    #if DEBUG
    func loadDataStoreFromDebug () {
        let decoder = JSONDecoder ()
        
        func decode<T: Decodable> (_ file: String) -> [T] {
            guard let data = try? Data (contentsOf: URL (fileURLWithPath: file)) else {
                abort ()
            }
            return try! decoder.decode ([T].self, from: data)
        }
//        hosts = decode ("/tmp/swiftterm-debug.hosts")
//        keys = decode ("/tmp/swiftterm-debug.keys")
//        snippets = decode ("/tmp/swiftterm-debug.snippets")
    }
    
    func dumpData () {
        let coder = JSONEncoder ()

        func encode<T:Encodable> (_ file: String, _ values: [T]) {
            let data = try! coder.encode(values)
            try! data.write(to: URL (fileURLWithPath: file))
        }
//        encode ("/tmp/swiftterm-debug.hosts", hosts)
//        encode ("/tmp/swiftterm-debug.keys", keys)
//        encode ("/tmp/swiftterm-debug.snippets", snippets)
    }
#endif

    func loadDataStoreFromDefaults () {
        defaults = UserDefaults (suiteName: "SwiftTermApp")
//        let decoder = JSONDecoder ()
//        if let d = defaults {
//            if let data = d.data(forKey: hostsArrayKey) {
//                if let h = try? decoder.decode ([Host].self, from: data) {
//                    hosts = h
//                }
//            }
//            for host in hosts {
//                host.loadKeychainElements()
//            }
//            if let data = d.data(forKey: keysArrayKey) {
//                if let k = try? decoder.decode ([Key].self, from: data) {
//                    keys = k
//                }
//            }
//            for key in keys {
//                key.loadKeychainElements ()
//            }
//
//            if let data = d.data(forKey: snippetArrayKey) {
//                if let s = try? decoder.decode ([Snippet].self, from: data) {
//                    snippets = s
//                }
//            }
//        }
        loadKnownHosts()
    }
    
    // Saves the data store
    func saveState ()
    {
        guard let d = defaults else {
            return
        }
        // If we ever get something again, it goes here
        d.synchronize()
        saveKnownHosts ()
    }
    
    func saveSnippets () {
        guard let d = defaults else {
            return
        }
        let coder = JSONEncoder ()
        if let snippetData = try? coder.encode(snippets) {
            d.set (snippetData, forKey: snippetArrayKey)
        }
        d.synchronize()
    }
    
    var idToHost: [UUID:Host] = [:]
    
    func loadKnownHosts ()
    {
        guard let content = try? String (contentsOfFile: knownHostsPath) else {
            return
        }
        
        func makeRecord (part: [Substring]) -> KnownHost? {
            guard part.count >= 3 else {
                return nil
            }
            return KnownHost (host: String (part [0]),
                           keyType: String (part [1]),
                           key: String (part[2]),
                           rest: part [3...].map { String ($0) }.joined(separator: " "),
                           id: UUID ())
        }
        knownHosts.removeAll()
        for line in content.split(separator: "\n") {
            guard let record = makeRecord(part: line.split (separator: " ")) else { continue }
            knownHosts.append(record)
        }
    }
    
    func saveKnownHosts () {
        var res = ""
        for record in knownHosts {
            res += "\(record.host) \(record.keyType) \(record.key) \(record.rest)\n"
        }
        try? res.write(toFile: knownHostsPath, atomically: true, encoding: .utf8)
    }
    
    static var shared: DataStore = DataStore()
}
