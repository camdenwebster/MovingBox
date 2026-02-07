import MovingBoxAIDomain
import XCTest

@testable import MovingBoxAICore

final class AIResponseDecoderTests: XCTestCase {
    func testDecodeImageDetailsSuccess() throws {
        let json = """
            {
              "title": "Desk",
              "quantity": "1",
              "description": "Wood desk",
              "make": "IKEA",
              "model": "MALM",
              "category": "Furniture",
              "location": "Office",
              "price": "$199",
              "serialNumber": ""
            }
            """

        let details = try AIResponseDecoder.decodeImageDetails(from: json)
        XCTAssertEqual(details.title, "Desk")
        XCTAssertEqual(details.category, "Furniture")
    }

    func testDecodeImageDetailsThrowsOnInvalidJSON() {
        XCTAssertThrowsError(try AIResponseDecoder.decodeImageDetails(from: "not-json")) { error in
            guard case OpenAIError.invalidData = error else {
                return XCTFail("Expected OpenAIError.invalidData")
            }
        }
    }

    func testDecodeMultiItemSuccess() throws {
        let json = """
            {
              "items": [
                {
                  "id": "a1",
                  "title": "Lamp",
                  "description": "Table lamp",
                  "category": "Lighting",
                  "make": "Target",
                  "model": "L100",
                  "estimatedPrice": "$40",
                  "confidence": 0.88
                }
              ],
              "detectedCount": 1,
              "analysisType": "multi_item",
              "confidence": 0.9
            }
            """

        let result = try AIResponseDecoder.decodeMultiItemResponse(from: json)
        XCTAssertEqual(result.safeItems.count, 1)
        XCTAssertEqual(result.safeItems[0].title, "Lamp")
    }
}
