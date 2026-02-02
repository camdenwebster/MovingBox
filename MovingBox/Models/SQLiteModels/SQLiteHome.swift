import Foundation
import SQLiteData

@Table("homes")
nonisolated struct SQLiteHome: Hashable, Identifiable {
    let id: UUID
    var name: String = ""
    var address1: String = ""
    var address2: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var country: String = ""
    var purchaseDate: Date = Date()
    @Column(as: Decimal.TextRepresentation.self)
    var purchasePrice: Decimal = 0
    var imageURL: URL?
    @Column(as: JSONArrayRepresentation<String>.self)
    var secondaryPhotoURLs: [String] = []
    var isPrimary: Bool = false
    var colorName: String = "green"
}
