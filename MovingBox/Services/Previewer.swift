//
//  Previewer.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import UIKit

@MainActor
struct Previewer {
    let container: ModelContainer
    let inventoryItem: InventoryItem
    let location: InventoryLocation
    let label: InventoryLabel
    let home: Home
    let policy: InsurancePolicy
    
    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self,
            configurations: config
        )
        
        // MARK: - Preview location
        location = InventoryLocation(name: "Office", desc: "Camden's office")
        container.mainContext.insert(location)
        
        // MARK: - Preview label
        label = InventoryLabel(name: "Electronics", desc: "Electronic items", color: .red)
        container.mainContext.insert(label)
        
        // MARK: - Preview inventory item
        inventoryItem = InventoryItem(
            title: "Sennheiser Power Adapter",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "Sennheiser",
            model: "Power adapter",
            make: "Sennheiser",
            location: location,
            label: label,
            price: Decimal.zero,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )
        container.mainContext.insert(inventoryItem)
        
        // MARK: - Preview home
        
        home = Home(name: "Camden's Home", address1: "123 Main St", city: "Anytown", state: "CA", zip: 12345, country: "USA")
        container.mainContext.insert(home)
        
        // MARK: - Preview insurance policy
        policy = InsurancePolicy(
            providerName: "State Farm",
            policyNumber: "123456789",
            deductibleAmount: 1000,
            dwellingCoverageAmount: 500000,
            personalPropertyCoverageAmount: 100000,
            lossOfUseCoverageAmount: 5000,
            liabilityCoverageAmount: 300000,
            medicalPaymentsCoverageAmount: 5000,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        )
        
        container.mainContext.insert(policy)
    }
}
