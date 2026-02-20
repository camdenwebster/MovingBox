import Foundation
import SQLiteData
import SwiftUI

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
    var isPrimary: Bool = false
    var colorName: String = "green"
    var householdID: SQLiteHousehold.ID?
    var isPrivate: Bool = false

    init(
        id: UUID,
        name: String = "",
        address1: String = "",
        address2: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        country: String = "",
        purchaseDate: Date = Date(),
        purchasePrice: Decimal = 0,
        isPrimary: Bool = false,
        colorName: String = "green",
        householdID: SQLiteHousehold.ID? = nil,
        isPrivate: Bool = false
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
        self.isPrimary = isPrimary
        self.colorName = colorName
        self.householdID = householdID
        self.isPrivate = isPrivate
    }

    var displayName: String {
        name.isEmpty ? "Unnamed Home" : name
    }

    var color: Color {
        Color.homeColor(for: colorName)
    }
}

extension Color {
    static func homeColor(for name: String) -> Color {
        switch name {
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
}
