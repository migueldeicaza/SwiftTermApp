//
//  ColumnSelector.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/28/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct ColumnSelector: View {
    @State private var selectedCols = 0
    
    var body: some View {
        HStack {
            Text ("Columns")
            Spacer ()
            Picker("Columns", selection: $selectedCols) {
                Text("60").tag(60)
                Text("80").tag(80)
                Text("132").tag(132)
            }
            .pickerStyle(.segmented)
        }
    }
}

struct ColumnSelector_Previews: PreviewProvider {
    static var previews: some View {
        ColumnSelector()
    }
}
