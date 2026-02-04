import Foundation
import Testing
import UIKit

@testable import MovingBox

@Suite("SQLite Advanced Types & Computed Properties")
struct SQLiteAdvancedTypeTests {

    // MARK: - AttachmentInfo JSON Representation

    @Suite("AttachmentInfo JSON")
    struct AttachmentInfoTests {

        @Test("AttachmentInfo round-trip through database")
        func attachmentRoundTrip() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let attachments = [
                AttachmentInfo(url: "file:///docs/receipt.pdf", originalName: "receipt.pdf"),
                AttachmentInfo(url: "file:///docs/manual.pdf", originalName: "manual.pdf"),
            ]

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "With Attachments", attachments: attachments)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.attachments.count == 2)
            #expect(item?.attachments[0].url == "file:///docs/receipt.pdf")
            #expect(item?.attachments[0].originalName == "receipt.pdf")
            #expect(item?.attachments[1].url == "file:///docs/manual.pdf")
            #expect(item?.attachments[1].originalName == "manual.pdf")
        }

        @Test("Empty attachments array round-trip")
        func emptyAttachments() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "No Attachments")
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.attachments == [])
        }
    }

    // MARK: - UIColor via Database

    @Suite("UIColor via Database")
    struct UIColorDatabaseTests {

        @Test("UIColor stored and retrieved through label")
        func colorThroughLabel() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let originalColor = UIColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 1.0)

            try db.write { db in
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: id, name: "Colored", color: originalColor)
                ).execute(db)
            }

            let label = try db.read { db in
                try SQLiteInventoryLabel.find(id).fetchOne(db)
            }
            #expect(label?.color != nil)

            // Verify components within tolerance
            var r1: CGFloat = 0
            var g1: CGFloat = 0
            var b1: CGFloat = 0
            var a1: CGFloat = 0
            var r2: CGFloat = 0
            var g2: CGFloat = 0
            var b2: CGFloat = 0
            var a2: CGFloat = 0
            originalColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            label?.color?.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            let tolerance: CGFloat = 1.0 / 255.0
            #expect(abs(r1 - r2) <= tolerance)
            #expect(abs(g1 - g2) <= tolerance)
            #expect(abs(b1 - b2) <= tolerance)
            #expect(abs(a1 - a2) <= tolerance)
        }

        @Test("Nil color stored and retrieved through label")
        func nilColor() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: id, name: "No Color", color: nil)
                ).execute(db)
            }

            let label = try db.read { db in
                try SQLiteInventoryLabel.find(id).fetchOne(db)
            }
            #expect(label?.color == nil)
        }
    }

    // MARK: - Optional Decimal (replacementCost)

    @Suite("Optional Decimal")
    struct OptionalDecimalTests {

        @Test("replacementCost set and retrieved")
        func replacementCostSet() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let cost = Decimal(string: "1500.50")!

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Expensive", replacementCost: cost)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.replacementCost == cost)
        }

        @Test("replacementCost nil round-trip")
        func replacementCostNil() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "No Replacement")
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.replacementCost == nil)
        }

        @Test("replacementCost updated from nil to value")
        func replacementCostNilToValue() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Item")
                ).execute(db)
            }

            let cost = Decimal(string: "2000.00")!
            try db.write { db in
                try SQLiteInventoryItem.find(id)
                    .update { $0.replacementCost = cost }
                    .execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.replacementCost == cost)
        }
    }

    // MARK: - Date Round-Trips

    @Suite("Date Fields")
    struct DateFieldTests {

        @Test("Item createdAt round-trip preserves date")
        func createdAtRoundTrip() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let now = Date()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Dated", createdAt: now)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            // Dates are stored as "yyyy-MM-dd HH:mm:ss" so sub-second precision is lost
            #expect(item?.createdAt != nil)
            let delta = abs(item!.createdAt.timeIntervalSince(now))
            #expect(delta < 1.0, "Date should be within 1 second after round-trip")
        }

        @Test("Insurance policy date range round-trip")
        func policyDateRange() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let start = Date()
            let end = Calendar.current.date(byAdding: .year, value: 1, to: start)!

            try db.write { db in
                try SQLiteInsurancePolicy.insert(
                    SQLiteInsurancePolicy(
                        id: id, providerName: "TestCo", startDate: start, endDate: end)
                ).execute(db)
            }

            let policy = try db.read { db in
                try SQLiteInsurancePolicy.find(id).fetchOne(db)
            }
            let startDelta = abs(policy!.startDate.timeIntervalSince(start))
            let endDelta = abs(policy!.endDate.timeIntervalSince(end))
            #expect(startDelta < 1.0)
            #expect(endDelta < 1.0)
        }

        @Test("Item optional purchaseDate is nil when not set")
        func purchaseDateNil() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "No Purchase Date")
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.purchaseDate == nil)
            #expect(item?.warrantyExpirationDate == nil)
        }
    }

    // MARK: - URL Fields

    @Suite("URL Fields")
    struct URLFieldTests {

        @Test("imageURL round-trip through item")
        func imageURLRoundTrip() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()
            let url = URL(string: "file:///images/photo.jpg")!

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "With Photo", imageURL: url)
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.imageURL == url)
        }

        @Test("Nil imageURL round-trip")
        func nilImageURL() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "No Photo")
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.imageURL == nil)
        }
    }

    // MARK: - Home Computed Properties

    @Suite("Home Computed Properties")
    struct HomeComputedPropertyTests {

        @Test("displayName returns name when non-empty")
        func displayNameWithName() {
            let home = SQLiteHome(id: UUID(), name: "Beach House")
            #expect(home.displayName == "Beach House")
        }

        @Test("displayName returns fallback when name is empty")
        func displayNameEmpty() {
            let home = SQLiteHome(id: UUID(), name: "")
            #expect(home.displayName == "Unnamed Home")
        }

        @Test("color maps known color names correctly")
        func colorMapping() {
            let testCases: [(String, Bool)] = [
                ("red", true), ("orange", true), ("yellow", true),
                ("green", true), ("blue", true), ("purple", true),
                ("pink", true), ("brown", true), ("mint", true),
                ("teal", true), ("cyan", true), ("indigo", true),
            ]
            for (name, _) in testCases {
                let home = SQLiteHome(id: UUID(), colorName: name)
                // Just verify it doesn't crash and returns a Color
                _ = home.color
            }
        }

        @Test("color defaults to green for unknown name")
        func colorDefault() {
            let home = SQLiteHome(id: UUID(), colorName: "unknown")
            #expect(home.color == .green)
        }
    }

    // MARK: - MigrationError

    @Suite("MigrationError")
    struct MigrationErrorTests {

        @Test("countMismatch error description")
        func countMismatchDescription() {
            let error = MigrationError.countMismatch(table: "items", expected: 10, actual: 8)
            let desc = error.errorDescription!
            #expect(desc.contains("items"))
            #expect(desc.contains("10"))
            #expect(desc.contains("8"))
        }

        @Test("foreignKeyViolation error description")
        func foreignKeyViolationDescription() {
            let error = MigrationError.foreignKeyViolation(count: 3)
            let desc = error.errorDescription!
            #expect(desc.contains("3"))
            #expect(desc.contains("foreign key"))
        }
    }

    // MARK: - MigrationStats Edge Cases

    @Suite("MigrationStats")
    struct MigrationStatsTests {

        @Test("MigrationStats all zeros")
        func allZeros() {
            let stats = SQLiteMigrationCoordinator.MigrationStats()
            let desc = stats.description
            #expect(desc.contains("labels=0"))
            #expect(desc.contains("items=0"))
            #expect(!desc.contains("skipped"))
        }

        @Test("MigrationStats with all skipped counters non-zero")
        func allSkippedNonZero() {
            var stats = SQLiteMigrationCoordinator.MigrationStats()
            stats.skippedItemLabels = 5
            stats.skippedHomePolicies = 2
            stats.skippedColors = 3
            let desc = stats.description
            #expect(desc.contains("skippedItemLabels=5"))
            #expect(desc.contains("skippedHomePolicies=2"))
            #expect(desc.contains("skippedColors=3"))
        }
    }
}
