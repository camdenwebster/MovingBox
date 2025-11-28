import XCTest
import AVFoundation
@testable import MovingBox

@MainActor
final class CameraDeviceManagerTests: XCTestCase {
    var manager: CameraDeviceManager!

    override func setUp() {
        super.setUp()
        // Create manager for back camera
        manager = CameraDeviceManager(position: .back)
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Camera Discovery Tests

    func testCameraDiscoveryReturnsAvailableCameras() {
        // The manager should discover at least the wide angle camera on any device
        XCTAssertGreaterThan(manager.availableCameras.count, 0, "Should discover at least one camera")
    }

    func testDiscoveredCamerasHaveValidCapabilities() {
        for capability in manager.availableCameras {
            // Check min/max zoom factors are valid
            XCTAssertGreaterThan(capability.maxZoomFactor, 0, "Max zoom should be positive")
            XCTAssertGreaterThan(capability.minZoomFactor, 0, "Min zoom should be positive")
            XCTAssertLessThanOrEqual(
                capability.minZoomFactor,
                capability.maxZoomFactor,
                "Min zoom should be <= max zoom"
            )

            // Check focus distance is valid
            XCTAssertGreaterThanOrEqual(capability.minimumFocusDistance, -1, "Focus distance should be >= -1")

            // Check display zoom factor
            XCTAssertGreaterThan(capability.displayZoomFactor, 0, "Display zoom should be positive")
        }
    }

    func testWideAngleAlwaysHas1xZoom() {
        let wideAngle = manager.availableCameras.first { $0.displayZoomFactor == 1.0 }
        XCTAssertNotNil(wideAngle, "Should find a 1.0x (wide angle) camera")
    }

    func testUltraWideHasLessThan1xZoom() {
        let ultraWide = manager.availableCameras.first { $0.displayZoomFactor < 1.0 }
        if ultraWide != nil {
            // If ultra-wide exists, verify it's around 0.5x
            XCTAssertLessThan(ultraWide!.displayZoomFactor, 0.7)
        }
        // Note: Not all devices have ultra-wide, so this is optional
    }

    func testTelephotoHasGreaterThan1xZoom() {
        let telephoto = manager.availableCameras.first { $0.displayZoomFactor > 1.0 }
        if telephoto != nil {
            // If telephoto exists, verify it's at least 3x
            XCTAssertGreaterThanOrEqual(telephoto!.displayZoomFactor, 3.0)
        }
        // Note: Not all devices have telephoto, so this is optional
    }

    // MARK: - Zoom Level Calculation Tests

    func testOptimalZoomLevelsAreSorted() {
        let levels = manager.optimalZoomLevels
        XCTAssertEqual(levels, levels.sorted(), "Zoom levels should be sorted in ascending order")
    }

    func testOptimalZoomLevelsInclude1x() {
        let levels = manager.optimalZoomLevels
        XCTAssertTrue(levels.contains(1.0), "1.0x should always be in optimal zoom levels")
    }

    func testOptimalZoomLevelsMatchAvailableCameras() {
        let levels = manager.optimalZoomLevels
        let cameraZooms = manager.availableCameras.map { $0.displayZoomFactor }

        for level in levels {
            XCTAssertTrue(cameraZooms.contains(level), "Zoom level \(level) should match a camera")
        }
    }

    // MARK: - Camera Selection Tests

    func testCanGetCameraForZoomLevel() {
        for level in manager.optimalZoomLevels {
            let camera = manager.camera(forZoomLevel: level)
            XCTAssertNotNil(camera, "Should get camera for zoom level \(level)")
            XCTAssertEqual(camera?.displayZoomFactor, level, "Camera zoom should match requested level")
        }
    }

    func testCameraSelectionReturnsNilForUnavailableZoom() {
        let unavailableZoom: CGFloat = 100.0
        let camera = manager.camera(forZoomLevel: unavailableZoom)
        XCTAssertNil(camera, "Should return nil for unavailable zoom level")
    }

    func testBestCameraForMacroIsAvailable() {
        let macro = manager.bestCameraForMacro()
        XCTAssertNotNil(macro, "Should find a camera for macro photography")
    }

    func testBestCameraForMacroHasShortestFocusDistance() {
        let macro = manager.bestCameraForMacro()
        let allFocusDistances = manager.availableCameras.map { $0.minimumFocusDistance }

        if let macro = macro, !allFocusDistances.isEmpty {
            let minDistance = allFocusDistances.min() ?? Int.max
            XCTAssertLessThanOrEqual(
                macro.minimumFocusDistance,
                minDistance,
                "Macro camera should have shortest or tied focus distance"
            )
        }
    }

    // MARK: - Macro Recommendation Tests

    func testMacroRecommendationNotReturnedWhenAlreadyOnBestCamera() {
        let macro = manager.bestCameraForMacro()
        if let macro = macro {
            let recommendation = manager.checkMacroRecommendation(
                currentDevice: macro.device,
                currentZoom: macro.displayZoomFactor
            )
            XCTAssertNil(recommendation, "Should not recommend switching when already on best camera")
        }
    }

    func testMacroRecommendationHasValidMessage() {
        // Find a non-macro camera
        let nonMacro = manager.availableCameras.max { $0.minimumFocusDistance > $1.minimumFocusDistance }
        let macro = manager.bestCameraForMacro()

        if let nonMacro = nonMacro, let macro = macro, nonMacro.device != macro.device {
            let recommendation = manager.checkMacroRecommendation(
                currentDevice: nonMacro.device,
                currentZoom: nonMacro.displayZoomFactor
            )

            if let recommendation = recommendation {
                XCTAssertFalse(recommendation.message.isEmpty, "Message should not be empty")
                XCTAssertTrue(
                    recommendation.message.contains("0.5x") || recommendation.message.contains("closer"),
                    "Message should mention zoom or distance improvement"
                )
            }
        }
    }

    func testMacroRecommendationIncludesCorrectImprovement() {
        let nonMacro = manager.availableCameras.max { $0.minimumFocusDistance > $1.minimumFocusDistance }
        let macro = manager.bestCameraForMacro()

        if let nonMacro = nonMacro, let macro = macro, nonMacro.device != macro.device {
            let recommendation = manager.checkMacroRecommendation(
                currentDevice: nonMacro.device,
                currentZoom: nonMacro.displayZoomFactor
            )

            if let recommendation = recommendation {
                let expectedImprovement = nonMacro.minimumFocusDistance - macro.minimumFocusDistance
                XCTAssertEqual(
                    recommendation.focusDistanceImprovement,
                    expectedImprovement,
                    "Improvement should be difference in focus distances"
                )
            }
        }
    }

    // MARK: - Zoom Support Tests

    func testCanAchieveZoomReturnsTrueForSupportedZoom() {
        for level in manager.optimalZoomLevels {
            XCTAssertTrue(
                manager.canAchieveZoom(level),
                "Should report support for zoom level \(level)"
            )
        }
    }

    func testCanAchieveZoomReturnsFalseForUnsupportedZoom() {
        let unsupported: CGFloat = 999.0
        XCTAssertFalse(manager.canAchieveZoom(unsupported), "Should not support extreme zoom")
    }

    // MARK: - Front Camera Tests

    func testCanCreateManagerForFrontCamera() {
        let frontManager = CameraDeviceManager(position: .front)
        // Front camera should also have at least wide angle
        XCTAssertGreaterThan(
            frontManager.availableCameras.count,
            0,
            "Front camera should have at least one camera"
        )
    }

    // MARK: - Zoom Factor Formatting Tests

    func testDisplayLabelForHalfZoom() {
        let capability = manager.availableCameras.first { $0.displayZoomFactor == 0.5 }
        if let capability = capability {
            XCTAssertEqual(capability.displayLabel, "0.5x")
        }
    }

    func testDisplayLabelForIntegerZoom() {
        let capability = manager.availableCameras.first { $0.displayZoomFactor == 1.0 }
        if let capability = capability {
            XCTAssertEqual(capability.displayLabel, "1x")
        }
    }

    func testDisplayLabelForDecimalZoom() {
        let capability = manager.availableCameras.first { $0.displayZoomFactor == 3.0 }
        if let capability = capability {
            XCTAssertEqual(capability.displayLabel, "3x")
        }
    }
}
