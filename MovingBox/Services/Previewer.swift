//
//  Previewer.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
struct Previewer {
    let container: ModelContainer
    let home: Home
    let location: InventoryLocation
    let newLocation2: InventoryLocation
    let label: InventoryLabel
    let inventoryItem: InventoryItem
    let policy: InsurancePolicy

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try ModelContainer(
            for: InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self,
            configurations: config
        )

        // Create all models first using local variables
        let newHome = {
            let home = Home()
            home.name = "My Home"
            home.address1 = "123 Main Street"

            if let url = Bundle.main.url(forResource: "craftsman-home", withExtension: "jpg") {
                home.imageURL = url
            }
            return home
        }()

        let newLocation = {
            let location = InventoryLocation()
            location.name = "Office"
            location.desc = "Camden's office"

            if let url = Bundle.main.url(forResource: "desk-chair", withExtension: "jpg") {
                location.imageURL = url
            }
            return location
        }()

        let newLocation2 = {
            let location = InventoryLocation()
            location.name = "Bedroom"
            location.desc = "Camden's bedroom"

            if let url = Bundle.main.url(forResource: "bed-frame", withExtension: "jpg") {
                location.imageURL = url
            }
            return location
        }()

        let newLabel = InventoryLabel(name: "Electronics", desc: "Electronic items", color: .red)

        let newItem = {
            let item = InventoryItem(
                title: "WA-87 Condenser Mic",
                quantityString: "1",
                quantityInt: 1,
                desc: "",
                serial: "WA-123",
                model: "WA-87",
                make: "WARM Audio",
                location: newLocation,
                labels: [newLabel],
                price: 599.99,
                insured: false,
                assetId: "",
                notes: "",
                showInvalidQuantityAlert: false,
                hasUsedAI: false
            )

            if let url = Bundle.main.url(forResource: "microphone", withExtension: "jpg") {
                item.imageURL = url
            }
            return item
        }()

        let newPolicy = InsurancePolicy(
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

        // Insert all models into the container
        container.mainContext.insert(newHome)
        container.mainContext.insert(newLocation)
        container.mainContext.insert(newLocation2)
        container.mainContext.insert(newLabel)
        container.mainContext.insert(newItem)
        container.mainContext.insert(newPolicy)

        // Assign to properties
        self.home = newHome
        self.location = newLocation
        self.newLocation2 = newLocation2
        self.label = newLabel
        self.inventoryItem = newItem
        self.policy = newPolicy
    }
}
