//
//  DataStore.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import Combine

// TODO: maybe the `type` could be an enum with Swift 5.5?
class Key: Codable, Identifiable {
    var id: UUID
    var type: KeyType = .rsa(4096)
    var name: String = ""
    
    // This stores the private key as pasted by the user, or if it is a type = .ecdsa(inSecureEnclave:true) the tag for the key in the KeyChain
    var privateKey: String = ""
    // This stores the public key as pasted by the user
    var publicKey: String = ""
    var passphrase: String = ""
    
    // If this is set to the empty string, it means that it has not been stored yet on the keychain
    var keyTag: String = ""
    
    // The list of keys that are serialized to Json, this is used to prevent both
    // passphrase and privateKey from being stored in plaintext.
    enum CodingKeys: CodingKey {
        case id
        case type
        case name
        case publicKey
        case keyTag
        #if DEBUG
        case passphrase
        case privateKey
        #endif
    }
    
    public init (id: UUID = UUID(), type: KeyType = .rsa(4096), name: String = "", privateKey: String = "", publicKey: String = "", passphrase: String = "")
    {
        self.id = id
        self.type = type
        self.name = name
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.passphrase = passphrase
    }
    
    /// If the key is stored in the KeyChain, returns the handle
    public func getKeyHandle () -> SecKey? {
        switch type  {
            case .ecdsa(inEnclave: true):
                let query = Key.getKeyQuery(forId: id)
                var result: CFTypeRef!
                
                if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess && result != nil {
                    return (result as! SecKey)
                }
            return nil
        default:
            return nil
        }
    }
    
    /// Saves the private components into the keychain
    public func saveKeychainElements () -> OSStatus {
        
        if keyTag == "" {
            keyTag = id.uuidString
            let (query, _) = getPassphraseQuery(id: keyTag, password: passphrase)
            let status = SecItemAdd(query, nil)
            guard status == errSecSuccess else {
                return status
            }
            let (queryKey, _) = getPrivateKeyQuery(id: keyTag, key: privateKey)
            let status2 = SecItemAdd(queryKey, nil)
            return status2
        } else {
            let (query, attrsToUpdate) = getPassphraseQuery(id: keyTag, password: passphrase, split: true)
            let status = SecItemUpdate(query, attrsToUpdate)
            guard status == errSecSuccess else {
                return status
            }
            let (queryKey, attrsToUpdateKey) = getPrivateKeyQuery(id: keyTag, key: privateKey, split: true)
            let status2 = SecItemUpdate(queryKey, attrsToUpdateKey as CFDictionary)
            return status2
        }
    }
    
    /// Load the private components from the keychain
    public func loadKeychainElements () {
        let (query, _) = getPassphraseQuery(id: keyTag, password: nil, fetch: true)
        
        var itemCopy: AnyObject?
        let status = SecItemCopyMatching(query, &itemCopy)
        if status != errSecSuccess {
            print ("oops")
        }
        if let d = itemCopy as? Data {
            passphrase = String (bytes: d, encoding: .utf8) ?? ""
        } else {
            passphrase = ""
        }
        let (queryKey, _) = getPrivateKeyQuery(id: keyTag, key: nil, fetch: true)
        let status2 = SecItemCopyMatching(queryKey, &itemCopy)
        if status2 != errSecSuccess {
            print ("oops")
        }
        if let ic = itemCopy as? Data {
            privateKey = String (bytes: ic, encoding: .utf8) ?? ""
        }
    }
    
    ///
    public func getPublicKeyAsData () -> Data {
        let values = publicKey.split (separator: " ")
        if values.count > 2 {
            if let decoded =  Data (base64Encoded: String (values [1])) {
                return decoded
            }
        }
        return Data()
    }
    
    /// Returns a CFData suitable to store on the keychain for the given UUID (which we use to identify the key).
    public static func getIdForKeychain (forId: UUID) -> CFData {
        return "SwiftTermApp-\(forId.uuidString)".data(using: .utf8)! as CFData
    }
    
    /// Returns a dictionary array suitable to be used as a `query` parameter for the various SecKey operations on the keychain
    public static func getKeyQuery (forId: UUID) -> CFDictionary {
        let query: [String:Any] = [
          kSecClass as String: kSecClassKey,
          kSecAttrApplicationTag as String: getIdForKeychain(forId: forId),
          kSecReturnRef as String: true
        ]
        return query as CFDictionary
    }
}

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
    func summary() -> String {
        hostname + (style != "" ? ", \(style)" : "")
    }
    
    /// Saves the private components into the keychain
    public func saveKeychainElements () -> OSStatus {
        let (query, _) = getHostPasswordQuery(id: id.uuidString, password: password)
        
        let status = SecItemAdd(query, nil)
        if status == errSecDuplicateItem {
            let (query2, update) = getHostPasswordQuery(id: id.uuidString, password: password, split: true)
            let status2 = SecItemUpdate(query2, update)
            return status2
        }
        return status
    }
    
    func loadKeychainElements () {
        let (query, _) = getHostPasswordQuery(id: id.uuidString, password: nil, fetch: true)

        var itemCopy: AnyObject?
        let status = SecItemCopyMatching(query, &itemCopy)
        if status != errSecSuccess {
            print ("oops")
        }
        if let d = itemCopy as? Data {
            password = String (bytes: d, encoding: .utf8) ?? ""
        } else {
            password = ""
        }
    }
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
    static let testKey1 = Key (id: UUID(), type: .rsa (1024), name: "Fake Legacy Key", privateKey: "", publicKey: "", passphrase: "")
    static let testKey2 = Key (id: UUID(), type: .rsa (4096), name: "Fake 2020 iPhone Key", privateKey: "", publicKey: "", passphrase: "")
    
    static let testUuid2 = UUID ()
    
    var defaults: UserDefaults?
    
    @Published var hosts: [Host] = [
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
        let decoder = JSONDecoder ()
        if let d = defaults {
//            if let data = d.data(forKey: hostsArrayKey) {
//                if let h = try? decoder.decode ([Host].self, from: data) {
//                    hosts = h
//                }
//            }
//            for host in hosts {
//                host.loadKeychainElements()
//            }
            if let data = d.data(forKey: keysArrayKey) {
                if let k = try? decoder.decode ([Key].self, from: data) {
                    keys = k
                }
            }
            for key in keys {
                key.loadKeychainElements ()
            }
            
            if let data = d.data(forKey: snippetArrayKey) {
                if let s = try? decoder.decode ([Snippet].self, from: data) {
                    snippets = s
                }
            }
        }
        loadKnownHosts()
    }
    
    // Saves the data store
    func saveState ()
    {
        guard let d = defaults else {
            return
        }
        // First save the host passwords in the keychain
        for host in hosts {
            let status = host.saveKeychainElements()
            if status != errSecSuccess {
                let result = SecCopyErrorMessageString(status, nil).debugDescription
                print ("error saving data for host \(host.alias) \(host.id) -> \(result)")
            }
        }
        
        let coder = JSONEncoder ()
//        if let hostData = try? coder.encode(hosts) {
//            d.set (hostData, forKey: hostsArrayKey)
//        }
        
        // First save the keys in the keychain, this assigns the keyTag if not set before
        for key in keys {
            let status = key.saveKeychainElements ()
            if status != errSecSuccess {
                let result = SecCopyErrorMessageString(status, nil).debugDescription
                print ("error saving data for key \(key.name) \(key.id) -> \(result)")
            }
        }

        // Now save the regular data
        if let keyData = try? coder.encode (keys) {
            d.set (keyData, forKey: keysArrayKey)
        }
        
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
    func save (host: Host)
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

    func removeKeys (atOffsets offsets: IndexSet) {
        for x in offsets {
            let key = keys [x]
            switch key.type {
            case .ecdsa(inEnclave: true):
                let query = Key.getKeyQuery(forId: key.id)
                SecItemDelete(query)
            default:
                break
            }
        }
        keys.remove(atOffsets: offsets)
    }
    
    func removeHosts (atOffsets offsets: IndexSet) {
        for x in offsets {
            let host = hosts [x]
            let (query, _) = getHostPasswordQuery(id: host.id.uuidString, password: nil)
            SecItemDelete(query)
        }
        hosts.remove(atOffsets: offsets)
        updateHostMap()
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
        if let idx = keys.firstIndex(where: { $0.id == key.id }) {
            keys.remove(at: idx)
            keys.insert(key, at: idx)
        } else {
            keys.append(key)
        }
        saveState ()
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
    
    // Returns the most recent `limit` values
    func recentIndices (limit: Int = 3) -> [Int]
    {
        var res: [Int] = []
        let sorted = hosts.sorted(by: {a, b in a.lastUsed > b.lastUsed })
        for x in sorted.prefix(limit) {
            if let idx = hosts.firstIndex(where: {$0.id == x.id }) {
                res.append(idx)
            }
        }
        return res
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
