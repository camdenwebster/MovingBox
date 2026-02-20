import XCTest

@testable import MovingBoxModules

final class PackageHarnessTests: XCTestCase {
    func testSmokeCheck() {
        XCTAssertTrue(PackageHarness.smokeCheck())
    }
}
