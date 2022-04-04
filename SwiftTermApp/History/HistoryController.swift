//
//  HistoryRecord.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/30/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

// Simplified version of a CLLocation, that can be serialized
struct HistoryLocation: Codable, Identifiable {
    var id = UUID()
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

let historyEncoder = JSONEncoder()
let historyDecoder = JSONDecoder()

enum HistoryOperation: Codable {
    case none
    case connected (at: HistoryLocation?)
    case disconnected (at: HistoryLocation?)
    case moved (newLocation: HistoryLocation?)
    
    func getAsData () -> Data {
        return (try? historyEncoder.encode(self)) ?? Data()
    }
}

extension HistoryRecord {
    // Used to
    @objc var renderedDate: String {
        guard let date = date else {
            return "Unknown"
        }
        return dateMediumFormatter.string(from: date)
    }
    
    var alias: String {
        guard let hid = hostId else { return "" }
        guard let host = DataStore.shared.idToHost [hid] else { return "" }
        return host.alias
    }
    
    var typedEvent: HistoryOperation {
        guard let d = event else { return .none }
        guard let v = try? historyDecoder.decode(HistoryOperation.self, from: d) else {
            return .none
        }
        return v
    }
}


class HistoryController: ObservableObject {
    let container = NSPersistentContainer(name: "History")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
}
