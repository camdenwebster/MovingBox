import Foundation
import SQLiteData

@Table("inventoryItems")
nonisolated struct SQLiteInventoryItem: Hashable, Identifiable {
    let id: UUID

    // MARK: - Core Properties
    var title: String = ""
    var quantityString: String = "1"
    var quantityInt: Int = 1
    var desc: String = ""
    var serial: String = ""
    var model: String = ""
    var make: String = ""

    // MARK: - Financial
    @Column(as: Decimal.TextRepresentation.self)
    var price: Decimal = 0
    var insured: Bool = false
    var assetId: String = ""
    var notes: String = ""
    @Column(as: Decimal.TextRepresentation?.self)
    var replacementCost: Decimal?
    var depreciationRate: Double?

    // MARK: - Images
    var imageURL: URL?
    @Column(as: JSONArrayRepresentation<String>.self)
    var secondaryPhotoURLs: [String] = []

    // MARK: - AI & Metadata
    var hasUsedAI: Bool = false
    var createdAt: Date = Date()

    // MARK: - Purchase & Ownership
    var purchaseDate: Date?
    var warrantyExpirationDate: Date?
    var purchaseLocation: String = ""
    var condition: String = ""
    var hasWarranty: Bool = false

    // MARK: - Attachments
    @Column(as: JSONArrayRepresentation<AttachmentInfo>.self)
    var attachments: [AttachmentInfo] = []

    // MARK: - Physical Properties
    var dimensionLength: String = ""
    var dimensionWidth: String = ""
    var dimensionHeight: String = ""
    var dimensionUnit: String = "inches"
    var weightValue: String = ""
    var weightUnit: String = "lbs"
    var color: String = ""
    var storageRequirements: String = ""

    // MARK: - Moving & Insurance
    var isFragile: Bool = false
    var movingPriority: Int = 3
    var roomDestination: String = ""

    // MARK: - Foreign Keys
    var locationID: SQLiteInventoryLocation.ID?
    var homeID: SQLiteHome.ID?

    var thumbnailURL: URL? {
        guard let imageURL = imageURL else { return nil }
        let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
        return OptimizedImageManager.shared.getThumbnailURL(for: id)
    }
}
