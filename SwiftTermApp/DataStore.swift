//
//  DataStore.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import Combine


/// Represents a host we connect to, the data structure we save, and keep at runtime
/// Most properties are used at connection time, and a handful can be changed at runtime:
///
/// Properties that can be changed at runtime:
/// - style:
/// - background
/// - backspaceAsControlH
///
/// Possibly should add; Font and FontSize
#if false
class Host: Codable, Identifiable {
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
    
    // The list of keys that are serialized to Json, this is used to prevent both
    // password from being stored in plaintext.
    enum CodingKeys: CodingKey {
        case id
        case alias
        case hostname
        case backspaceAsControlH
        case port
        case usePassword
        case username
        case hostKind
        case environmentVariables
        case startupScripts
        case sshKey
        case style
        case background
        case lastUsed
        case reconnectType
        #if DEBUG
        case password
        #endif
    }

    // Unique ID, used inside Swift to differentiate structures
    var id = UUID()
    
    // Public name for this host
    var alias: String = ""
    
    // Address to connect to
    var hostname: String = ""
    
    // Setting for this host, should the backspace key send a control-h
    var backspaceAsControlH: Bool = false
    
    // The port to which we will connect in the host
    var port: Int = 22
    
    // If true, this host uses a password, rather than a key
    var usePassword: Bool = true
    
    // Username to login as
    var username: String = ""
    
    // If usePassword is set, this might contain the password to provide for authentication
    var password: String = ""
    
    // The guessed host type - this is used to pick the icon for the host, and it is sometimes automatically guessed and set
    var hostKind: String = ""
    
    /// Environment variables to pass on the connection
    var environmentVariables: [String:String] = [:]
    
    /// Scripts to execute on startup
    var startupScripts: [String] = []
    
    // This is the UUID of the key registered with the app
    var sshKey: UUID?
    
    /// The current color theme style name, if the style is "" it means "use the default"
    var style: String = ""
    
    /// The values are `default` to pick the value from settings, "" to use a solid color, or the name of a live background
    var background: String = ""
    
    /// Last time this host was used, to show the sorted list of hosts used
    var lastUsed: Date = Date.distantPast
    
    /// Reconnection type, one of "" or "tmux"
    var reconnectType: String = ""
}
#else
extension Host {
    /// Saves the private components into the keychain
//    public func saveKeychainElements () -> OSStatus {
//        let (query, _) = getHostPasswordQuery(id: id.uuidString, password: password)
//        
//        let status = SecItemAdd(query, nil)
//        if status == errSecDuplicateItem {
//            let (query2, update) = getHostPasswordQuery(id: id.uuidString, password: password, split: true)
//            let status2 = SecItemUpdate(query2, update)
//            return status2
//        }
//        return status
//    }
//    
//    func loadKeychainElements () {
//        let (query, _) = getHostPasswordQuery(id: id.uuidString, password: nil, fetch: true)
//
//        var itemCopy: AnyObject?
//        let status = SecItemCopyMatching(query, &itemCopy)
//        if status != errSecSuccess {
//            print ("oops")
//        }
//        if let d = itemCopy as? Data {
//            password = String (bytes: d, encoding: .utf8) ?? ""
//        } else {
//            password = ""
//        }
//    }
}
#endif

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
    
    @Published var hosts: [CHost] = [
       //Host(alias: "Dummy MacPro",         hostname: "192.168.86.220", lastUsed: Date ()),
       //Host(alias: "Dummy Raspberri Pi",   hostname: "raspberry.tirania.org", lastUsed: Date ()),
       //Host(alias: "Dummy MacBook",        hostname: "road.tirania.org", usePassword: false, sshKey: DataStore.testKey1.id),
       //Host(alias: "Dummy Old Vax",        hostname: "oldvax.tirania.org",usePassword: false, sshKey: DataStore.testKey2.id),
       //Host(alias: "Dummy Old DECStation", hostname: "decstation.tirania.org"),
    ]
    
    @Published var keys: [Key] = [
        //testKey1, testKey2
    ]
    
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
        for host in hosts {
            idToHost [host.id] = host
        }
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
    
    // Records the new host in the data store
    func save (host: CHost)
    {
        if let idx = hosts.firstIndex (where: { $0.alias == host.alias }) {
            hosts.remove(at: idx)
            hosts.insert(host, at: idx)
        } else {
            hosts.append(host)
        }
        updateHostMap()
        saveState ()
    }
    
    func used (host: Host)
    {
        if let f = hosts.firstIndex(where: {$0.id == host.id}){
            hosts [f].lastUsed = Date()
            saveState()
        }
    }

    func hasHost (withAlias: String) -> Bool
    {
        hosts.contains { $0.alias == withAlias }
    }
    
    func keyExistsInStore (key: UUID) -> Bool {
        let c = keys.contains { $0.id == key }
        return c
    }

    func updateKind (for target: Host, to guess: String)
    {
        for i in 0..<hosts.count {
            if hosts [i].id == target.id {
                hosts [i].hostKind = guess
            }
        }
        saveState()
    }

    // This for now returns the name, but if it is ambiguous, it could return a hash or something else
    func getKeyDisplayName (forKey: UUID) -> String {
        if let k = keys.first(where: { $0.id == forKey }) {
            return k.name
        }
        return "none"
    }
    
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
