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
@MainActor
final class Home {
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
    var insurancePolicy: InsurancePolicy?
    
    @MainActor
    var photo: UIImage? {
        get async throws {
            guard let imageURL else { return nil }
            
            // First try to load from the URL directly
            if FileManager.default.fileExists(atPath: imageURL.path) {
                return try await OptimizedImageManager.shared.loadImage(url: imageURL)
            }
            
            // If the file doesn't exist at the original path, try loading using the ID
            let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
            
            // Reconstruct the URL using OptimizedImageManager's base path
            if let baseURL = OptimizedImageManager.shared.baseURL {
                let newURL = baseURL.appendingPathComponent("\(id).jpg")
                if FileManager.default.fileExists(atPath: newURL.path) {
                    // Update the stored URL to the correct path
                    self.imageURL = newURL
                    return try await OptimizedImageManager.shared.loadImage(url: newURL)
                }
            }
            
            return nil
        }
    }
    
    @MainActor
    var thumbnail: UIImage? {
        get async throws {
            guard let imageURL else { return nil }
            let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
            return try await OptimizedImageManager.shared.loadThumbnail(id: id)
        }
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
    }
}
