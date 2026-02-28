import MovingBoxAIAnalysis
import Testing

@testable import MovingBox

@MainActor
@Suite("AI Analysis Response Safety Tests")
struct OpenAIStrictModeTests {
    @Test("safeItems is empty when items is nil")
    func testSafeItemsWithNilItems() {
        let response = MultiItemAnalysisResponse(
            items: nil,
            detectedCount: 2,
            analysisType: "multi_item",
            confidence: 0.8
        )

        #expect(response.safeItems.isEmpty)
        #expect(!response.isValid)
    }

    @Test("safeItems returns payload items when present")
    func testSafeItemsWithItems() {
        let item = DetectedInventoryItem(
            id: "detected-1",
            title: "Desk Chair",
            description: "Office chair",
            category: "Furniture",
            make: "",
            model: "",
            estimatedPrice: "$120",
            confidence: 0.9
        )

        let response = MultiItemAnalysisResponse(
            items: [item],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.9
        )

        #expect(response.safeItems.count == 1)
        #expect(response.safeItems.first?.title == "Desk Chair")
        #expect(response.isValid)
    }
}
