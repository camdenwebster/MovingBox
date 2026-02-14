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
