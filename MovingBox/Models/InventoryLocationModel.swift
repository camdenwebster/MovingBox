//
//  LocationModel.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class InventoryLocation: PhotoManageable {
    var name: String = ""
    var desc: String = ""
    var imageURL: URL?
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    init(name: String = "", desc: String = "") {
        self.name = name
        self.desc = desc
    }
}
