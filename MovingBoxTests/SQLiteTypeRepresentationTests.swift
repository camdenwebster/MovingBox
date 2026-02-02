import Foundation
import Testing
import UIKit

@testable import MovingBox

@Suite("SQLite Type Representations")
struct SQLiteTypeRepresentationTests {

    // MARK: - UIColor Hex Representation

    @Suite("UIColor Hex")
    struct UIColorHexTests {

        @Test("Round-trip: solid red")
        func solidRed() {
            let original = UIColor.red
            let rep = UIColor.HexRepresentation(queryOutput: original)
            let hex = rep.hexValue
            #expect(hex != nil)
            let restored = UIColor.HexRepresentation(hexValue: hex!)
            assertColorsEqual(original, restored.queryOutput)
        }

        @Test("Round-trip: solid blue")
        func solidBlue() {
            let original = UIColor.blue
            let rep = UIColor.HexRepresentation(queryOutput: original)
            let hex = rep.hexValue
            #expect(hex != nil)
            let restored = UIColor.HexRepresentation(hexValue: hex!)
            assertColorsEqual(original, restored.queryOutput)
        }

        @Test("Round-trip: custom RGBA color")
        func customRGBA() {
            let original = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
            let rep = UIColor.HexRepresentation(queryOutput: original)
            let hex = rep.hexValue
            #expect(hex != nil)
            let restored = UIColor.HexRepresentation(hexValue: hex!)
            assertColorsEqual(original, restored.queryOutput, tolerance: 1.0 / 255.0)
        }

        @Test("Hex value is deterministic")
        func deterministic() {
            let color = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
            let rep = UIColor.HexRepresentation(queryOutput: color)
            // Red = 0xFF000000 shifted + 0x00FF0000 green + 0x0000FF00 blue + 0x000000FF alpha
            // For pure red: R=255, G=0, B=0, A=255
            // hex = (255 << 24) | (0 << 16) | (0 << 8) | 255 = 0xFF0000FF
            #expect(rep.hexValue == 0xFF00_00FF)
        }

        private func assertColorsEqual(
            _ a: UIColor, _ b: UIColor, tolerance: CGFloat = 0.01
        ) {
            var r1: CGFloat = 0
            var g1: CGFloat = 0
            var b1: CGFloat = 0
            var a1: CGFloat = 0
            var r2: CGFloat = 0
            var g2: CGFloat = 0
            var b2: CGFloat = 0
            var a2: CGFloat = 0
            a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            #expect(abs(r1 - r2) <= tolerance, "Red mismatch: \(r1) vs \(r2)")
            #expect(abs(g1 - g2) <= tolerance, "Green mismatch: \(g1) vs \(g2)")
            #expect(abs(b1 - b2) <= tolerance, "Blue mismatch: \(b1) vs \(b2)")
            #expect(abs(a1 - a2) <= tolerance, "Alpha mismatch: \(a1) vs \(a2)")
        }
    }

    // MARK: - Decimal Text Representation

    @Suite("Decimal Text")
    struct DecimalTextTests {

        @Test("Round-trip through database: precise value")
        func preciseValueThroughDB() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let precisePrice = Decimal(string: "1234567890.123456789")!

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Test", price: precisePrice)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.price == precisePrice)
        }

        @Test("Round-trip: zero")
        func zero() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Free Item", price: 0)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.price == 0)
        }

        @Test("Round-trip: negative value")
        func negativeValue() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let negativePrice = Decimal(string: "-99.99")!

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Refund", price: negativePrice)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.price == negativePrice)
        }
    }

    // MARK: - JSON Array Representation

    @Suite("JSON Array via Database")
    struct JSONArrayDBTests {

        @Test("String array round-trip through database")
        func stringArrayRoundTrip() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let photos = ["photo1.jpg", "photo2.jpg", "photo3.jpg"]

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Photos Test", secondaryPhotoURLs: photos)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.secondaryPhotoURLs == photos)
        }

        @Test("Empty array round-trip through database")
        func emptyArrayRoundTrip() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "No Photos")
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.secondaryPhotoURLs == [])
        }
    }
}
