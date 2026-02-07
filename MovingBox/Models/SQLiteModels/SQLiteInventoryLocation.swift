import Foundation
import SQLiteData

@Table("inventoryLocations")
nonisolated struct SQLiteInventoryLocation: Hashable, Identifiable {
    let id: UUID
    var name: String = ""
    var desc: String = ""
    var sfSymbolName: String?
    var imageURL: URL?
    @Column(as: [String].JSONRepresentation.self)
    var secondaryPhotoURLs: [String] = []
    var homeID: SQLiteHome.ID?

    var thumbnailURL: URL? {
        guard let imageURL = imageURL else { return nil }
        let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
        return OptimizedImageManager.shared.getThumbnailURL(for: id)
    }
}

extension SQLiteInventoryLocation: PhotoManageable {}
