//
//  LabelModel.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData

@Model
class InventoryLabel {
    var id: String = ""
    var name: String = ""
    var desc: String = ""
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    init(id: String, name: String, desc: String) {
        self.id = id
        self.name = name
        self.desc = desc
    }
}
