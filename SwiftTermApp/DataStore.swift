//
//  DataStore.swift
//  testMasterDetail
//
//  Created by Miguel de Icaza on 4/26/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import Combine

struct Host: Codable, Identifiable {
    let id = UUID()
    var alias: String = ""
    var hostname: String = ""
    var backspaceAsControlH: Bool = false
    var port: Int = 22
    var username: String = ""
    var password: String = ""
    var style: String = ""
    var lastUsed: Date = Date.distantPast
}

class DataStore: ObservableObject {
    @Published var hosts: [Host] = [
        Host(alias: "MacPro",         hostname: "mac.tirania.org", lastUsed: Date ()),
        Host(alias: "Raspberri Pi",   hostname: "raspberry.tirania.org", lastUsed: Date ()),
        Host(alias: "MacBook",        hostname: "road.tirania.org"),
        Host(alias: "Old Vax",        hostname: "oldvax.tirania.org"),
        Host(alias: "Old DECStation", hostname: "decstation.tirania.org"),
    ]

    // Returns the most recent 3 values
    func recentIndices () -> Range<Int>
    {
        hosts.sorted(by: {a, b in a.lastUsed > b.lastUsed }).prefix(3).indices
    }
    static var shared: DataStore = DataStore()
}
