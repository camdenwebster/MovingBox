import Testing

@testable import MovingBoxAIAnalysis

@Suite("AI Response Parser")
struct AIResponseParserTests {

    let parser = AIResponseParser()

    // MARK: - sanitizeString tests

    @Test("sanitizeString returns empty for 'unknown'")
    func sanitizeUnknown() {
        #expect(parser.sanitizeString("unknown") == "")
        #expect(parser.sanitizeString("Unknown") == "")
        #expect(parser.sanitizeString("UNKNOWN") == "")
    }

    @Test("sanitizeString returns empty for 'n/a' variants")
    func sanitizeNA() {
        #expect(parser.sanitizeString("n/a") == "")
        #expect(parser.sanitizeString("N/A") == "")
        #expect(parser.sanitizeString("na") == "")
        #expect(parser.sanitizeString("None") == "")
        #expect(parser.sanitizeString("not available") == "")
    }

    @Test("sanitizeString returns empty for bad substrings")
    func sanitizeBadSubstrings() {
        #expect(parser.sanitizeString("no serial number found") == "")
        #expect(parser.sanitizeString("Serial number not found on item") == "")
        #expect(parser.sanitizeString("not visible in image") == "")
        #expect(parser.sanitizeString("Unable to determine the price") == "")
    }

    @Test("sanitizeString preserves valid values")
    func sanitizeValidValues() {
        #expect(parser.sanitizeString("MacBook Pro") == "MacBook Pro")
        #expect(parser.sanitizeString("  Apple  ") == "Apple")
        #expect(parser.sanitizeString("$299.99") == "$299.99")
    }

    @Test("sanitizeString returns empty for empty/whitespace input")
    func sanitizeEmpty() {
        #expect(parser.sanitizeString("") == "")
        #expect(parser.sanitizeString("   ") == "")
        #expect(parser.sanitizeString("\n\t") == "")
    }

    // MARK: - sanitizeImageDetails tests

    @Test("sanitizeImageDetails cleans all fields")
    func sanitizeImageDetailsCleanup() {
        let dirty = ImageDetails(
            title: "Unknown Item",
            quantity: "1",
            description: "A nice laptop",
            make: "n/a",
            model: "not available",
            category: "Electronics",
            location: "Unknown",
            price: "$999",
            serialNumber: "no serial number found"
        )

        let cleaned = parser.sanitizeImageDetails(dirty)

        #expect(cleaned.title == "")
        #expect(cleaned.quantity == "1")
        #expect(cleaned.description == "A nice laptop")
        #expect(cleaned.make == "")
        #expect(cleaned.model == "")
        #expect(cleaned.category == "Electronics")
        #expect(cleaned.location == "")
        #expect(cleaned.price == "$999")
        #expect(cleaned.serialNumber == "")
    }

    // MARK: - sanitizeDetectedItem tests

    @Test("sanitizeDetectedItem cleans fields and preserves confidence")
    func sanitizeDetectedItemCleanup() {
        let dirty = DetectedInventoryItem(
            title: "Laptop",
            description: "Unknown",
            category: "n/a",
            make: "Apple",
            model: "not visible",
            estimatedPrice: "$1200",
            confidence: 0.95,
            detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [100, 200, 500, 800])]
        )

        let cleaned = parser.sanitizeDetectedItem(dirty)

        #expect(cleaned.title == "Laptop")
        #expect(cleaned.description == "")
        #expect(cleaned.category == "")
        #expect(cleaned.make == "Apple")
        #expect(cleaned.model == "")
        #expect(cleaned.estimatedPrice == "$1200")
        #expect(cleaned.confidence == 0.95)
        #expect(cleaned.detections?.count == 1)
    }

    // MARK: - sanitizeMultiItemResponse tests

    @Test("sanitizeMultiItemResponse sanitizes all items")
    func sanitizeMultiItemResponseCleanup() {
        let response = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    title: "Unknown Item",
                    description: "A chair",
                    category: "Furniture",
                    make: "n/a",
                    model: "",
                    estimatedPrice: "$200",
                    confidence: 0.8
                ),
                DetectedInventoryItem(
                    title: "Table",
                    description: "not available",
                    category: "Furniture",
                    make: "IKEA",
                    model: "KALLAX",
                    estimatedPrice: "$150",
                    confidence: 0.9
                ),
            ],
            detectedCount: 2,
            analysisType: "multi_item",
            confidence: 0.85
        )

        let cleaned = parser.sanitizeMultiItemResponse(response)

        #expect(cleaned.safeItems.count == 2)
        #expect(cleaned.safeItems[0].title == "")
        #expect(cleaned.safeItems[0].make == "")
        #expect(cleaned.safeItems[1].title == "Table")
        #expect(cleaned.safeItems[1].description == "")
        #expect(cleaned.safeItems[1].make == "IKEA")
        #expect(cleaned.detectedCount == 2)
        #expect(cleaned.confidence == 0.85)
    }

    @Test("sanitizeMultiItemResponse handles nil items")
    func sanitizeMultiItemResponseNilItems() {
        let response = MultiItemAnalysisResponse(
            items: nil,
            detectedCount: 0,
            analysisType: "multi_item",
            confidence: 0.5
        )

        let cleaned = parser.sanitizeMultiItemResponse(response)

        #expect(cleaned.items == nil)
        #expect(cleaned.safeItems.isEmpty)
    }
}
