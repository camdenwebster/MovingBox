import Foundation
import Testing
import UIKit

@testable import MovingBox

@Suite("CloudKit Recovery Coordinator", .serialized)
struct CloudKitRecoveryCoordinatorTests {

    // MARK: - RecoveryStats

    @Test("RecoveryStats description format")
    func recoveryStatsDescription() {
        var stats = CloudKitRecoveryCoordinator.RecoveryStats()
        stats.labels = 3
        stats.homes = 1
        stats.policies = 1
        stats.locations = 5
        stats.items = 20
        stats.itemLabels = 10
        stats.homePolicies = 1

        let desc = stats.description
        #expect(desc.contains("labels=3"))
        #expect(desc.contains("homes=1"))
        #expect(desc.contains("policies=1"))
        #expect(desc.contains("locations=5"))
        #expect(desc.contains("items=20"))
        #expect(desc.contains("itemLabels=10"))
        #expect(desc.contains("homePolicies=1"))
        #expect(!desc.contains("skippedRelationships"))
    }

    @Test("RecoveryStats includes skippedRelationships when non-zero")
    func recoveryStatsWithSkipped() {
        var stats = CloudKitRecoveryCoordinator.RecoveryStats()
        stats.items = 5
        stats.skippedRelationships = 2

        let desc = stats.description
        #expect(desc.contains("skippedRelationships=2"))
    }

    @Test("RecoveryStats omits skippedRelationships when zero")
    func recoveryStatsOmitsZeroSkipped() {
        var stats = CloudKitRecoveryCoordinator.RecoveryStats()
        stats.items = 5
        stats.skippedRelationships = 0

        let desc = stats.description
        #expect(!desc.contains("skipped"))
    }

    // MARK: - Color Hex Conversion

    @Test("UIColor data converts to hex RGBA Int64")
    func colorDataToHex() throws {
        let color = UIColor.red
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: color, requiringSecureCoding: true)

        let hex = SQLiteRecordWriter.colorHexFromData(data)
        #expect(hex != nil)
        // Red = 0xFF0000FF
        #expect(hex == 0xFF00_00FF)
    }

    @Test("Invalid color data returns fallback gray")
    func invalidColorDataReturnsFallback() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        let hex = SQLiteRecordWriter.colorHexFromData(invalidData)
        #expect(hex == 0x8080_80FF)
    }

    @Test("UIColor blue converts correctly")
    func blueColorConversion() throws {
        let color = UIColor.blue
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: color, requiringSecureCoding: true)

        let hex = SQLiteRecordWriter.colorHexFromData(data)
        #expect(hex != nil)
        // Blue = 0x0000FFFF
        #expect(hex == 0x0000_FFFF)
    }

    // MARK: - Decimal Conversion

    @Test("Decimal from CK Double preserves common values")
    func decimalFromDouble() {
        let result = SQLiteRecordWriter.decimalFromDouble(99.99)
        #expect("\(result)" == "99.99")
    }

    @Test("Decimal from nil returns zero")
    func decimalFromNil() {
        let result = SQLiteRecordWriter.decimalFromDouble(nil)
        #expect(result == 0)
    }

    @Test("Decimal from zero")
    func decimalFromZero() {
        let result = SQLiteRecordWriter.decimalFromDouble(0.0)
        #expect(result == 0)
    }

    // MARK: - Plist to JSON Conversion

    @Test("Plist array data converts to JSON string")
    func plistToJSON() throws {
        let array = ["photo1.jpg", "photo2.jpg"]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: array, format: .binary, options: 0)

        // Create a minimal CKRecord-like test by directly calling the helper
        // We test the underlying logic rather than CKRecord wrapping
        let jsonString = plistDataToJSON(plistData)
        #expect(jsonString.contains("photo1.jpg"))
        #expect(jsonString.contains("photo2.jpg"))
    }

    @Test("Empty data returns empty JSON array")
    func emptyDataReturnsEmptyArray() {
        let jsonString = plistDataToJSON(Data())
        #expect(jsonString == "[]")
    }

    // MARK: - Mark Complete / Idempotency

    private static let testRecoveryCompleteKey =
        "com.mothersound.movingbox.cloudkit.recovery.complete"

    @Test("markComplete sets UserDefaults flag")
    func markCompleteSetsFlag() {
        UserDefaults.standard.removeObject(forKey: Self.testRecoveryCompleteKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.testRecoveryCompleteKey) }

        CloudKitRecoveryCoordinator.markComplete()
        #expect(UserDefaults.standard.bool(forKey: Self.testRecoveryCompleteKey))
    }

    @Test("markComplete is idempotent")
    func markCompleteIdempotent() {
        UserDefaults.standard.removeObject(forKey: Self.testRecoveryCompleteKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.testRecoveryCompleteKey) }

        CloudKitRecoveryCoordinator.markComplete()
        CloudKitRecoveryCoordinator.markComplete()
        #expect(UserDefaults.standard.bool(forKey: Self.testRecoveryCompleteKey))
    }

    // MARK: - Probe Returns Nil When Complete

    @Test("probeForStrandedRecords returns nil when recovery is complete")
    func probeReturnsNilWhenComplete() async {
        UserDefaults.standard.set(true, forKey: Self.testRecoveryCompleteKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.testRecoveryCompleteKey) }

        let count = await CloudKitRecoveryCoordinator.probeForStrandedRecords()
        #expect(count == nil)
    }

    // MARK: - RecoveryError Descriptions (Fix 21)

    @Test("RecoveryError.foreignKeyViolation produces informative description")
    func foreignKeyViolationDescription() {
        let error = RecoveryError.foreignKeyViolation(count: 3)
        let description = error.errorDescription!
        #expect(description.contains("3"))
        #expect(description.contains("foreign key"))
    }

    @Test("RecoveryError.countMismatch produces informative description")
    func countMismatchDescription() {
        let error = RecoveryError.countMismatch(expected: 10, actual: 5)
        let description = error.errorDescription!
        #expect(description.contains("10"))
        #expect(description.contains("5"))
        #expect(description.contains("mismatch"))
    }

    // MARK: - Test Helpers

    /// Converts plist Data to JSON string (same logic as the coordinator)
    private func plistDataToJSON(_ data: Data) -> String {
        guard !data.isEmpty else { return "[]" }

        if let plistArray = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [Any],
            let jsonData = try? JSONSerialization.data(withJSONObject: plistArray, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }

        if let jsonString = String(data: data, encoding: .utf8),
            (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
        {
            return jsonString
        }

        return "[]"
    }
}
