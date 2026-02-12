//
//  Item.swift
//  WOYPplus
//
//  Created by Chris Davies on 12/02/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
