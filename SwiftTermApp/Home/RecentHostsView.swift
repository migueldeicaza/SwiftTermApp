//
//  RecentHostsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/5/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import CoreData

struct RecentHostsView: View {
    @State var limit = 3
    @FetchRequest
    var hosts: FetchedResults<CHost>
    
    init (limit: Int = 3) {
        _limit = State (initialValue: limit)
        let request: NSFetchRequest<CHost> = CHost.fetchRequest()

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CHost.sLastUsed, ascending: false)
        ]
        request.predicate = NSPredicate (format: "sLastUsed != nil")
        request.fetchLimit = limit
        _hosts = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        ForEach(hosts, id: \.self) { host in
            HostSummaryView (host: host)
        }
    }
}

struct RecentHostsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentHostsView()
    }
}
