//
//  InventoryItem.swift
//  FirebaseCRUD-CamdenW
//
//  Created by Camden Webster on 4/9/24.
//

import Foundation
import SwiftUI

class InventoryItem: Identifiable, ObservableObject {
    
    var locations: [String] = ["None", "Kitchen", "Office", "Bedroom", "Bathroom", "Hallway Closet", "Basement", "Attic"]
    var categories: [String] = ["None", "Musical instruments", "Kitchen appliances", "Decor", "Cooking Utensils", "Electronics", "Household Items"]
    
    var id: String
    @Published var title: String
    @Published var quantityString: String
    @Published var quantityInt: Int
    @Published var description: String
    @Published var serial: String
    @Published var model: String
    @Published var make: String
    @Published var location: String
    @Published var category: String
    @Published var price: String
    @Published var insured: Bool
    @Published var assetId: String
    @Published var notes: String
    
    @Published var showInvalidQuantityAlert: Bool
    
    var isInteger: Bool {
            return Int(quantityString) != nil
        }
    
    init(id: String = UUID().uuidString, title: String = "", quantityString: String = "1", quantityInt: Int = 1, description: String = "", serial: String = "", model: String = "", make: String = "", location: String = "None", category: String = "None", price: String = "", insured: Bool = false, assetId: String = "", notes: String = "", showInvalidQuantityAlert: Bool = false) {
        self.id = id
        self.title = title
        self.quantityString = quantityString
        self.quantityInt = quantityInt
        self.description = description
        self.serial = serial
        self.model = model
        self.make = make
        self.location = location
        self.category = category
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
            }
        }
}
