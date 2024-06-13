//
//  InventoryItemModel.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class InventoryItem: Identifiable, ObservableObject {
    var id: String
    var title: String
    var quantity: Int
    var desc: String
    var serial: String
    var model: String
    var make: String
    var location: InventoryLocation?
    var label: InventoryLabel?
    var price: String
    var insured: Bool
    var assetId: String
    var notes: String
    @Attribute(.externalStorage) var data: Data?
    var photo: UIImage? {
        if let data {
            return UIImage(data: data)
        } else {
            return nil
        }
    }
        
    init (id: String = "", title: String = "", quantity: Int = 1, desc: String = "", serial: String = "", model: String = "", make: String = "", location: InventoryLocation?, label: InventoryLabel?, price: String = "", insured: Bool = false, assetId: String = "", notes: String = "") {

        self.id = id
        self.title = title
        self.quantity = quantity
        self.desc = desc
        self.serial = serial
        self.model = model
        self.make = make
        self.location = location
        self.label = label
        self.price = price
        self.insured = insured
        self.assetId = assetId
        self.notes = notes
    }
}
