//
//  LocationModel.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class InventoryLocation {
    var name: String = ""
    var desc: String = ""
    var imageURL: URL?
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    // Efficient async computed properties for image loading
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
    
    init(name: String = "", desc: String = "") {
        self.name = name
        self.desc = desc
    }
}
