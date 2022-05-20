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
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
    }
    
    func deleteAll() {
        let fetchRequest1: NSFetchRequest<NSFetchRequestResult> = CHost.fetchRequest()
        let batchDeleteRequest1 = NSBatchDeleteRequest(fetchRequest: fetchRequest1)
        _ = try? container.viewContext.execute(batchDeleteRequest1)

        let fetchRequest2: NSFetchRequest<NSFetchRequestResult> = CKey.fetchRequest()
        let batchDeleteRequest2 = NSBatchDeleteRequest(fetchRequest: fetchRequest2)
        _ = try? container.viewContext.execute(batchDeleteRequest2)
    }
}
