//
//  DefaultHomeView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/15/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct DefaultHomeView: View {
    var body: some View {
        SessionsView()
    }
}

struct DefaultHomeView_Previews: PreviewProvider {
    static var previews: some View {
        DefaultHomeView()
    }
}
