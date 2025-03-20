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
    var name: String = ""
    var desc: String = ""
    @Attribute(.externalStorage) var data: Data?
    var photo: UIImage? {
        get {
            if let data = data {
                return UIImage(data: data)
            }
            return nil
        }
    }
    
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    init(name: String = "", desc: String = "") {
        self.name = name
        self.desc = desc
    }
}
