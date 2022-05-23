//
//  SnippetSummary.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/25/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct SnippetSummary: View {
    @State var snippet: CUserSnippet
    var body: some View {
        VStack (alignment: .leading){
            Text (snippet.title)
                .bold()
            Text (snippet.command)
                .lineLimit(1)
                .foregroundColor(.secondary)
                .font (.system (.body, design: .monospaced))
        }
    }
}

struct SnippetSummary_Previews: PreviewProvider {
    static var previews: some View {
        SnippetSummary(snippet: DataController.preview.createSampleSnippet())
    }
}
