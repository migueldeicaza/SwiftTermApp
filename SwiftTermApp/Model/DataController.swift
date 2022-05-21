//
//  DataController.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/16/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import CoreData
import SwiftUI
import CloudKit

class DataController: ObservableObject {
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        // Since we have a local database, and a cloud-synced database, the following set these up.
        // https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/setting_up_core_data_with_cloudkit
        let storeDirectory = NSPersistentContainer.defaultDirectoryURL()

        func getLocation (_ file: String) -> URL {
            if inMemory {
                return URL (fileURLWithPath: "/dev/null")
            }
            return storeDirectory.appendingPathComponent(file)
        }
        
        container = NSPersistentCloudKitContainer(name: "Main")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let localStoreDescription = NSPersistentStoreDescription(url: getLocation ("local.sqlite"))
        localStoreDescription.configuration = "Local"

        let cloudStoreDescription = NSPersistentStoreDescription(url: getLocation ("cloud.sqlite"))
        
        let cloudOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.org.tirania.SwiftTermKeys")
        cloudOptions.databaseScope = .private
        cloudStoreDescription.configuration = "Cloud"
        cloudStoreDescription.cloudKitContainerOptions = cloudOptions
        cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Update the container's list of store descriptions
        container.persistentStoreDescriptions = [
            cloudStoreDescription,
            localStoreDescription
        ]
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("Fatal error loading store: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func createSampleHost (_ i: Int) -> CHost {
        let host = CHost(context: container.viewContext)
        host.sAlias = "Host \(i)"
        host.sHostname = "foo-\(i).example.com"
        host.sUsername = "root"

        return host
    }
    
    func createSampleKey () -> CKey {
        let key = CKey (context: container.viewContext)
        key.id = UUID ()
        key.name = "My First Key"
        key.type = .rsa(1024)
        key.publicKey = "FAKE_PUBLIC_KEY"
        key.privateKey = "FAKE_PRIVATE_KEY"
        return key
    }
    
    func createSampleData() throws {
        let viewContext = container.viewContext

        for i in 1...5 {
            let _ = createSampleHost (i)
        }
        
        for k in 1...5 {
            let key = CKey (context: viewContext)
            key.sName = "My Key \(k)"
            key.sPublicKey = "GibberishPublicKey"
            
        }

        try viewContext.save()
    }
    
    static var preview: DataController = {
        let dataController = DataController(inMemory: true)
        let viewContext = dataController.container.viewContext

        do {
            try dataController.createSampleData()
        } catch {
            fatalError("Fatal error creating preview: \(error.localizedDescription)")
        }

        return dataController
    }()

    func save() {
        if container.viewContext.hasChanges {
            try? container.viewContext.save()
        }
    }
    
    func delete(host: CHost) {
        let (query, _) = getHostPasswordQuery(id: host.id.uuidString, password: nil)
        SecItemDelete(query)

        container.viewContext.delete(host)
    }

    func delete(key: CKey) {
        key.deleteKeychainCompanionData ()
        container.viewContext.delete(key)
    }
    
    func updateKind (hostId: UUID, newKind: String) {
        DispatchQueue.main.async {
            let h = CHost.fetchRequest()
            h.predicate = NSPredicate (format: "sId == %@", hostId.uuidString)
            let hosts = try? self.container.viewContext.fetch(h)
            if let host = hosts?.first {
                host.hostKind = newKind
            }
        }
    }
    
    func hasHost (withAlias: String) -> Bool {
        let h = CHost.fetchRequest()
        h.predicate = NSPredicate (format: "sAlias == %@", withAlias)
        let hosts = try? container.viewContext.fetch(h)
        return hosts?.count ?? 0 > 0
    }
    
    func keyExistsInStore(key: UUID) -> Bool {
        let kr = CKey.fetchRequest()
        kr.predicate = NSPredicate (format: "sId == %@", key.uuidString)
        let keys = try? container.viewContext.fetch(kr)
        return keys?.count ?? 0 > 0
    }
    
    // This for now returns the name, but if it is ambiguous, it could return a hash or something else
    func getKeyDisplayName (forKey: UUID) -> String {
        let kr = CKey.fetchRequest()
        kr.predicate = NSPredicate (format: "sId == %@", forKey.uuidString)
        let keys = try? container.viewContext.fetch(kr)
        if let key = keys?.first {
            return key.name
        }
        return "none"
    }

    func deleteAll() {
        let fetchRequest1: NSFetchRequest<NSFetchRequestResult> = CHost.fetchRequest()
        let batchDeleteRequest1 = NSBatchDeleteRequest(fetchRequest: fetchRequest1)
        _ = try? container.viewContext.execute(batchDeleteRequest1)

        let fetchRequest2: NSFetchRequest<NSFetchRequestResult> = CKey.fetchRequest()
        let batchDeleteRequest2 = NSBatchDeleteRequest(fetchRequest: fetchRequest2)
        _ = try? container.viewContext.execute(batchDeleteRequest2)
    }
    
    /// Flags the given host as used recently.
    func used (host: Host) {
        let request: NSFetchRequest<CHost> = CHost.fetchRequest()
        request.predicate = NSPredicate(format: "sId = \"\(host.id)\"")
        request.fetchLimit = 1
        if let result = try? container.viewContext.fetch(request) {
            if result.count > 0 {
                result [0].lastUsed = Date ()
                save ()
            }
        }
    }
}
