//
//  RecentHostsView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/5/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct RecentHostsView: View {
    @ObservedObject var store: DataStore = DataStore.shared
    @State var limit = 3
    var body: some View {
        ForEach(self.store.recentIndices (limit: limit), id: \.self) { idx in
            HostSummaryView (host: self.$store.hosts [idx])
        }
    }
}

struct RecentHostsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentHostsView()
    }
}
