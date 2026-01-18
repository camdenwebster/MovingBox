//
//  HomeModel.swift
//  MovingBox
//
//  Created by Camden Webster on 3/7/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class Home: PhotoManageable {
    var id: UUID = UUID()
    var name: String = ""
    var address1: String = ""
    var address2: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var country: String = ""
    var purchaseDate: Date = Date()
    var purchasePrice: Decimal = 0.00
    var imageURL: URL?
    var secondaryPhotoURLs: [String] = []
    var insurancePolicy: InsurancePolicy?
    var isPrimary: Bool = false
    var colorName: String = "green"

    // Inverse relationships for CloudKit compatibility
    @Relationship(inverse: \InventoryItem.home) var items: [InventoryItem]?
    @Relationship(inverse: \InventoryLocation.home) var locations: [InventoryLocation]?

    /// Display name for the home - uses name if provided, otherwise falls back to address1, then "Unnamed Home"
    var displayName: String {
        if !name.isEmpty {
            return name
        } else if !address1.isEmpty {
            return address1
        } else {
            return "Unnamed Home"
        }
    }

    var color: Color {
        get {
            switch colorName {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "mint": return .mint
            case "teal": return .teal
            case "cyan": return .cyan
            case "blue": return .blue
            case "indigo": return .indigo
            case "purple": return .purple
            case "pink": return .pink
            case "brown": return .brown
            default: return .green
            }
        }
        set {
            colorName = colorToName(newValue)
        }
    }

    private func colorToName(_ color: Color) -> String {
        switch color {
        case .red: return "red"
        case .orange: return "orange"
        case .yellow: return "yellow"
        case .green: return "green"
        case .mint: return "mint"
        case .teal: return "teal"
        case .cyan: return "cyan"
        case .blue: return "blue"
        case .indigo: return "indigo"
        case .purple: return "purple"
        case .pink: return "pink"
        case .brown: return "brown"
        default: return "green"
        }
    }

    // MARK: - Legacy Support
    @Attribute(.externalStorage) var data: Data?

    /// Migrates legacy image data to the new URL-based storage system
    func migrateImageIfNeeded() async throws {
        guard let legacyData = data,
            let image = UIImage(data: legacyData),
            imageURL == nil
        else {
            return
        }

        // Generate a unique identifier for the image
        let imageId = UUID().uuidString

        // Save the image using OptimizedImageManager
        imageURL = try await OptimizedImageManager.shared.saveImage(image, id: imageId)

        // Clear legacy data after successful migration
        data = nil

        print("📸 Home - Successfully migrated image for home: \(name)")
    }

    /// Creates a new Home instance with the specified parameters.
    /// - Parameters:
    ///   - name: The name of the home
    ///   - address1: Primary address line
    ///   - address2: Secondary address line (optional)
    ///   - city: City name
    ///   - state: State/Province name
    ///   - zip: ZIP/Postal code (as String to support international formats)
    ///   - country: Country name
    ///   - purchaseDate: Date of purchase (defaults to current date)
    ///   - purchasePrice: Purchase price (defaults to 0.00)
    ///   - insurancePolicy: Associated insurance policy (optional)
    init(
        id: UUID = UUID(),
        name: String = "",
        address1: String = "",
        address2: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        country: String = "",
        purchaseDate: Date = Date(),
        purchasePrice: Decimal = 0.00,
        insurancePolicy: InsurancePolicy? = nil
    ) {
        self.id = id
        self.name = name
        self.address1 = address1
        self.address2 = address2
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.insurancePolicy = insurancePolicy

        // Attempt migration on init
        Task {
            try? await migrateImageIfNeeded()
        }
    }
}
