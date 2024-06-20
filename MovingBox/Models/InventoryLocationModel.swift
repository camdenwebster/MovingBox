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
class InventoryLocation {
    var id: String = ""
    var name: String = ""
    var desc: String = ""
//    var parentLocation: InventoryLocation?
    @Attribute(.externalStorage) var data: Data?
    var photo: UIImage? {
        if let data {
            return UIImage(data: data)
        } else {
            return nil
        }
    }
    
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    init(id: String, name: String, desc: String) {
        self.id = id
        self.name = name
        self.desc = desc
    }
}
