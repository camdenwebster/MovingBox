import Foundation
import SwiftData
import SwiftUI

@Model
final class Home: PhotoManageable {
    var name: String = ""
    var address1: String = ""
    var address2: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var country: String = ""
    var purchaseDate: Date = Date()
    var purchasePrice: Decimal = 0.00
    var imageURLs: [URL] = []
    var primaryImageIndex: Int = 0
    
    @Attribute(.externalStorage) var data: Data?
    var imageURL: URL?
    
    init(
        name: String = "",
        address1: String = "",
        address2: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        country: String = "",
        purchaseDate: Date = Date(),
        purchasePrice: Decimal = 0.00
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
    }
    
    func migrateImageIfNeeded() async throws {
        guard let legacyData = data,
              let image = UIImage(data: legacyData),
              imageURLs.isEmpty else {
            return
        }
        
        let imageId = UUID().uuidString
        if let newImageURL = try await OptimizedImageManager.shared.saveImage(image, id: imageId) {
            imageURLs.append(newImageURL)
        }
        
        data = nil
        print("📸 Home - Successfully migrated image for home: \(name)")
    }
}
