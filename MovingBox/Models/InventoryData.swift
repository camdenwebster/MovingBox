//
//  InventoryData.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import Foundation

class InventoryData: ObservableObject {
    @Published var inventoryItems: [InventoryItem] = [
        InventoryItem(id: "42a827fe-fe72-4e86-9072-33cd414fe640", title: "Coffee maker", location: "Kitchen"),
        InventoryItem(id: "8ba720af-07a1-41d5-838e-752cf8126146", title: "Bean grinder", location: "Kitchen"),
        InventoryItem(id: "3b6a4069-0853-4855-985e-05d1f76cd70a", title: "Fender Telecaster", location: "Office"),
        InventoryItem(id: "5030e9a3-3626-45df-824d-03f1bb1d1383", title: "MacBook Pro", location: "Office")
    ]
}
