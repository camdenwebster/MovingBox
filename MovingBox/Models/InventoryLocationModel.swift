//
//  LocationModel.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData

@Model
class InventoryLocation {
    var id: String = ""
    var name: String = ""
    var desc: String = ""
//    var parentLocation: InventoryLocation?
    @Attribute(.externalStorage) var photo: Data?
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    init(id: String, name: String, desc: String) {
        self.id = id
        self.name = name
        self.desc = desc
    }
}
