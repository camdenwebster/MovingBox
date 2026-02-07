import XCTest

@testable import MovingBoxAIDomain

final class MultiItemAnalysisResponseTests: XCTestCase {
    func testSafeItemsReturnsEmptyForNilItems() {
        let response = MultiItemAnalysisResponse(
            items: nil, detectedCount: 0, analysisType: "multi_item", confidence: 0.9)
        XCTAssertEqual(response.safeItems, [])
        XCTAssertFalse(response.isValid)
    }

    func testIsValidRequiresCountMatchAndConfidenceThreshold() {
        let item = DetectedInventoryItem(
            id: "1",
            title: "Laptop",
            description: "Work laptop",
            category: "Electronics",
            make: "Apple",
            model: "MacBook Pro",
            estimatedPrice: "$1999",
            confidence: 0.8
        )

        let valid = MultiItemAnalysisResponse(
            items: [item], detectedCount: 1, analysisType: "multi_item", confidence: 0.9)
        XCTAssertTrue(valid.isValid)

        let badCount = MultiItemAnalysisResponse(
            items: [item], detectedCount: 2, analysisType: "multi_item", confidence: 0.9)
        XCTAssertFalse(badCount.isValid)

        let lowConfidence = MultiItemAnalysisResponse(
            items: [item], detectedCount: 1, analysisType: "multi_item", confidence: 0.4)
        XCTAssertFalse(lowConfidence.isValid)
    }
}
