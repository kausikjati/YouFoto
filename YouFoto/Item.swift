//
//  Item.swift
//  YouFoto
//
//  Created by Kausik Jati on 17/02/26.
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
