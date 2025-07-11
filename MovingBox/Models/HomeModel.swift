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
    
    // MARK: - Legacy Support
    @Attribute(.externalStorage) var data: Data?
    
    /// Migrates legacy image data to the new URL-based storage system
    func migrateImageIfNeeded() async throws {
        guard let legacyData = data,
              let image = UIImage(data: legacyData),
              imageURL == nil else {
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
