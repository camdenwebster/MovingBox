import XCTest

@testable import MovingBoxAIDomain

final class ImageDetailsTests: XCTestCase {
    func testDecodingAppliesDefaultsForMissingFields() throws {
        let json = """
            {
              "title": "Desk Lamp"
            }
            """

        let details = try JSONDecoder().decode(ImageDetails.self, from: Data(json.utf8))

        XCTAssertEqual(details.title, "Desk Lamp")
        XCTAssertEqual(details.quantity, "1")
        XCTAssertEqual(details.description, "Item details not available")
        XCTAssertEqual(details.category, "Uncategorized")
        XCTAssertEqual(details.categories, [])
        XCTAssertEqual(details.location, "Unknown")
        XCTAssertEqual(details.price, "$0.00")
    }

    func testDecodingUsesCategoriesArrayWhenPresent() throws {
        let json = """
            {
              "title": "Camera",
              "category": "Electronics",
              "categories": ["Electronics", "Photography", "Gear", "Extra"]
            }
            """

        let details = try JSONDecoder().decode(ImageDetails.self, from: Data(json.utf8))

        XCTAssertEqual(details.category, "Electronics")
        XCTAssertEqual(details.categories, ["Electronics", "Photography", "Gear"])
    }

    func testEmptyFactoryCreatesExpectedDefaults() {
        let details = ImageDetails.empty()
        XCTAssertEqual(details.category, "None")
        XCTAssertEqual(details.categories, [])
        XCTAssertEqual(details.location, "None")
    }
}
