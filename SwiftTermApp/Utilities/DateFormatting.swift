//
//  DateFormatting.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/31/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

let dateTimeFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

let timeStampFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .long
    return dateFormatter
}()

let timeFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .none
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

let dateMediumFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    return dateFormatter
}()
