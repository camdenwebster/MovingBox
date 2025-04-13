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
            return try await OptimizedImageManager.shared.loadImage(url: imageURL)
        }
    }
    
    @MainActor
    var thumbnail: UIImage? {
        get async throws {
            guard let imageURL else { return nil }
            let id = imageURL.deletingPathExtension().lastPathComponent
            return try await OptimizedImageManager.shared.loadThumbnail(id: id)
        }
    }
    
    init(name: String = "", desc: String = "") {
        self.name = name
        self.desc = desc
    }
}
