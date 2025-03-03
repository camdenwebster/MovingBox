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
class InventoryItem: ObservableObject {
    var title: String = ""
    var quantityString: String = "1"
    var quantityInt: Int = 1
    var desc: String = ""
    var serial: String = ""
    var model: String = ""
    var make: String = ""
    var location: InventoryLocation?
    var label: InventoryLabel?
    var price: Decimal = Decimal.zero
    var insured: Bool = false
    var assetId: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var data: Data?
    var photo: UIImage? {
        if let data {
            return UIImage(data: data)
        } else {
            return nil
        }
    }
    
    var showInvalidQuantityAlert: Bool = false
    
    var isInteger: Bool {
            return Int(quantityString) != nil
        }
    
    init(title: String, quantityString: String, quantityInt: Int, desc: String, serial: String, model: String, make: String, location: InventoryLocation?, label: InventoryLabel?, price: Decimal, insured: Bool, assetId: String, notes: String, showInvalidQuantityAlert: Bool) {

        self.title = title
        self.quantityString = quantityString
        self.quantityInt = quantityInt
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
        self.showInvalidQuantityAlert = showInvalidQuantityAlert
    }
    
    func validateQuantityInput() {
        if !isInteger {
            showInvalidQuantityAlert = true
        } else {
            self.quantityInt = Int(quantityString) ?? 1
            showInvalidQuantityAlert = false
        }
    }
    
}
