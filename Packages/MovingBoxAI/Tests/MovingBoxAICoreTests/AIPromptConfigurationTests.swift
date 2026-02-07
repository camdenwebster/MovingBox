import XCTest

@testable import MovingBoxAICore

final class AIPromptConfigurationTests: XCTestCase {
    func testAllEnabledPropertiesOverridesCategoryAndLocationEnums() {
        let categories = ["None", "Electronics", "Furniture"]
        let locations = ["None", "Garage", "Office"]

        let props = AIPromptConfiguration.allEnabledProperties(categories: categories, locations: locations)

        XCTAssertEqual(props["category"]?.enumValues ?? [], categories)
        XCTAssertEqual(props["location"]?.enumValues ?? [], locations)
    }

    func testCoreAndEnabledExtendedPropertiesAreIncluded() {
        let props = AIPromptConfiguration.allEnabledProperties(categories: ["None"], locations: ["None"])

        XCTAssertNotNil(props["title"])
        XCTAssertNotNil(props["condition"])
        XCTAssertNil(props["dimensions"], "Disabled properties should not be included")
    }
}
