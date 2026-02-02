import Foundation
import SQLiteData
import UIKit

// MARK: - UIColor Hex Representation

extension UIColor {
    /// Stores UIColor as an INTEGER (RGBA hex value) in SQLite.
    /// Follows the Color.HexRepresentation pattern from sqlite-data's Reminders example.
    nonisolated struct HexRepresentation: QueryBindable, QueryDecodable, QueryRepresentable {
        var queryOutput: UIColor

        init(queryOutput: UIColor) {
            self.queryOutput = queryOutput
        }

        init(hexValue: Int64) {
            self.init(
                queryOutput: UIColor(
                    red: CGFloat((hexValue >> 24) & 0xFF) / 0xFF,
                    green: CGFloat((hexValue >> 16) & 0xFF) / 0xFF,
                    blue: CGFloat((hexValue >> 8) & 0xFF) / 0xFF,
                    alpha: CGFloat(hexValue & 0xFF) / 0xFF
                )
            )
        }

        var hexValue: Int64? {
            guard let components = queryOutput.cgColor.components else { return nil }
            let r = Int64(components[0] * 0xFF) << 24
            let g = Int64(components[1] * 0xFF) << 16
            let b = Int64(components[2] * 0xFF) << 8
            let a = Int64((components.indices.contains(3) ? components[3] : 1) * 0xFF)
            return r | g | b | a
        }

        init?(queryBinding: QueryBinding) {
            guard case .int(let hexValue) = queryBinding else { return nil }
            self.init(hexValue: hexValue)
        }

        var queryBinding: QueryBinding {
            guard let hexValue else {
                struct InvalidColor: Error {}
                return .invalid(InvalidColor())
            }
            return .int(hexValue)
        }

        init(decoder: inout some QueryDecoder) throws {
            try self.init(hexValue: Int64(decoder: &decoder))
        }
    }
}

// MARK: - Decimal Text Representation

extension Decimal {
    /// Stores Decimal as TEXT in SQLite to avoid floating-point precision loss.
    nonisolated struct TextRepresentation: QueryBindable, QueryDecodable, QueryRepresentable {
        var queryOutput: Decimal

        init(queryOutput: Decimal) {
            self.queryOutput = queryOutput
        }

        init?(queryBinding: QueryBinding) {
            guard case .text(let string) = queryBinding else { return nil }
            guard let decimal = Decimal(string: string) else { return nil }
            self.init(queryOutput: decimal)
        }

        var queryBinding: QueryBinding {
            .text("\(queryOutput)")
        }

        init(decoder: inout some QueryDecoder) throws {
            let string = try String(decoder: &decoder)
            guard let decimal = Decimal(string: string) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Invalid decimal string: \(string)")
                )
            }
            self.init(queryOutput: decimal)
        }
    }
}

// MARK: - JSON Array Representation

/// Stores a Codable array as JSON TEXT in SQLite.
/// Used for `[String]` (secondaryPhotoURLs) and `[AttachmentInfo]` (attachments).
struct JSONArrayRepresentation<Element: Codable & Hashable & Sendable>: QueryBindable,
    QueryDecodable, QueryRepresentable, Sendable
{
    var queryOutput: [Element]

    init(queryOutput: [Element]) {
        self.queryOutput = queryOutput
    }

    init?(queryBinding: QueryBinding) {
        guard case .text(let jsonString) = queryBinding else { return nil }
        guard let data = jsonString.data(using: .utf8),
            let array = try? JSONDecoder().decode([Element].self, from: data)
        else {
            self.init(queryOutput: [])
            return
        }
        self.init(queryOutput: array)
    }

    var queryBinding: QueryBinding {
        guard let data = try? JSONEncoder().encode(queryOutput),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            return .text("[]")
        }
        return .text(jsonString)
    }

    init(decoder: inout some QueryDecoder) throws {
        let jsonString = try String(decoder: &decoder)
        guard let data = jsonString.data(using: .utf8) else {
            self.init(queryOutput: [])
            return
        }
        let array = (try? JSONDecoder().decode([Element].self, from: data)) ?? []
        self.init(queryOutput: array)
    }
}
