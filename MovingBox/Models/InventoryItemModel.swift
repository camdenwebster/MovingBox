//
//  InventoryItemModel.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class InventoryItem: ObservableObject {
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
    var imageURL: URL?
    
    @MainActor
    func loadPhoto() async throws -> UIImage? {
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
    
    @MainActor
    func loadThumbnail() async throws -> UIImage? {
        guard let imageURL else { return nil }
        let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
        return try await OptimizedImageManager.shared.loadThumbnail(id: id)
    }
    
    var showInvalidQuantityAlert: Bool = false
    
    var isInteger: Bool {
            return Int(quantityString) != nil
        }
    
    var hasUsedAI: Bool = false
    
    init() {}
    
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
        self.hasUsedAI = false
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
