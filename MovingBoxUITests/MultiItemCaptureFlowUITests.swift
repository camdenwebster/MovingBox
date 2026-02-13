import XCTest

@MainActor
final class MultiItemCaptureFlowUITests: XCTestCase {
    var dashboardScreen: DashboardScreen!
    var cameraScreen: CameraScreen!
    var multiItemSelectionScreen: MultiItemSelectionScreen!
    var navigationHelper: NavigationHelper!
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Is-Pro",
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
            "Disable-Animations",
            "Mock-AI",
        ]

        // Initialize screen objects
        dashboardScreen = DashboardScreen(app: app)
        cameraScreen = CameraScreen(app: app, testCase: self)
        multiItemSelectionScreen = MultiItemSelectionScreen(app: app)
        navigationHelper = NavigationHelper(app: app)

        setupSnapshot(app)
        app.launch()

        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }

    override func tearDownWithError() throws {
        dashboardScreen = nil
        cameraScreen = nil
        multiItemSelectionScreen = nil
        navigationHelper = nil
    }

    // MARK: - Camera Navigation Tests

    func testNavigationToCamera() throws {
        // Given: User is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: User taps the floating Add Item button
        XCTAssertTrue(
            dashboardScreen.addItemFromCameraButton.waitForExistence(timeout: 5),
            "Add Item button should be visible")
        dashboardScreen.addItemFromCameraButton.tap()

        // Then: Camera should open
        XCTAssertTrue(
            cameraScreen.waitForCamera(timeout: 5),
            "Camera should be displayed")
    }

    func testEmptyStateAddItemButtonNavigation() throws {
        // Given: User is on dashboard with empty state
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: User taps the empty state Add Item button
        if dashboardScreen.emptyStateAddItemButton.exists {
            dashboardScreen.emptyStateAddItemButton.tap()

            // Then: Camera should open
            XCTAssertTrue(
                cameraScreen.waitForCamera(timeout: 5),
                "Camera should be displayed")
        } else {
            throw XCTSkip("Empty state not available - test data might be loaded")
        }
    }

    // MARK: - Camera Mode Toggle Tests

    func testCameraModePicker() throws {
        // Given: User opens camera
        openCamera()

        // Then: Camera mode picker should be visible
        XCTAssertTrue(
            cameraScreen.modePicker.waitForExistence(timeout: 5),
            "Camera mode picker should be visible")
    }

    func testSwitchToMultiItemMode() throws {
        // Given: User opens camera (defaults to Single mode)
        openCamera()

        // When: User taps the Multi toggle in the segmented control
        let modePicker = app.segmentedControls.firstMatch
        XCTAssertTrue(
            modePicker.waitForExistence(timeout: 5),
            "Mode picker should be visible")

        let multiButton = modePicker.buttons["Multi"]
        XCTAssertTrue(multiButton.exists, "Multi button should exist")
        multiButton.tap()

        // Then: Mode should switch to Multi
        XCTAssertTrue(multiButton.isSelected, "Multi mode should be selected")
    }

    func testMultiItemModeProFeatureGating() throws {
        // Note: This test runs with "Is-Pro" launch argument
        // To test non-Pro behavior, would need a separate test without that argument

        // Given: User is a Pro subscriber (via launch argument)
        openCamera()

        // When: User switches to Multi mode
        let modePicker = app.segmentedControls.firstMatch
        if modePicker.waitForExistence(timeout: 5) {
            let multiButton = modePicker.buttons["Multi"]
            multiButton.tap()

            // Then: No paywall should appear (Pro user)
            let paywall = app.otherElements.containing(
                NSPredicate(format: "identifier CONTAINS 'paywall'")
            ).firstMatch
            XCTAssertFalse(
                paywall.waitForExistence(timeout: 2),
                "Paywall should not appear for Pro users")
        }
    }

    // MARK: - Multi-Item Photo Capture Tests

    func testMultiItemPhotoCaptureFlow() throws {
        // Given: User is in Multi mode
        openCamera()
        switchToMultiMode()

        // When: User taps shutter button
        cameraScreen.captureButton.tap()

        // Then: Preview overlay should appear
        XCTAssertTrue(
            cameraScreen.waitForPreviewOverlay(),
            "Preview overlay should appear after capture")
    }

    func testMultiItemRetakeButton() throws {
        // Given: User has captured a photo in Multi mode
        openCamera()
        switchToMultiMode()
        cameraScreen.takePhoto()

        XCTAssertTrue(
            cameraScreen.waitForPreviewOverlay(),
            "Preview overlay should appear after capture")

        // When: User taps retake button
        let retakeButton = app.buttons["multiItemRetakeButton"]
        XCTAssertTrue(retakeButton.exists, "Retake button should exist")
        retakeButton.tap()

        // Then: Should return to camera view
        XCTAssertFalse(
            cameraScreen.previewRetakeButton.exists,
            "Preview overlay should be dismissed")
        XCTAssertTrue(
            cameraScreen.captureButton.exists,
            "Camera shutter should be visible again")
    }

    // MARK: - Multi-Item Selection View Tests

    func testMultiItemSelectionViewAppears() throws {
        // Given: User goes through capture flow in Multi mode
        navigateToMultiItemSelection()

        // Then: Multi-item selection view should appear after analysis
        XCTAssertTrue(
            multiItemSelectionScreen.isDisplayed(),
            "Multi-item selection view should be visible")
    }

    func testMultiItemCardSelection() throws {
        // Given: User is on multi-item selection view with detected items
        navigateToMultiItemSelection()

        // When: User taps the first item card
        let itemCount = multiItemSelectionScreen.getItemCardCount()
        guard itemCount > 0 else {
            throw XCTSkip("No items detected in mock analysis")
        }

        multiItemSelectionScreen.tapItemCard(at: 0)

        // Then: Selection counter should update
        if let counterText = multiItemSelectionScreen.getSelectionCounterText() {
            XCTAssertTrue(
                counterText.contains("selected"),
                "Selection counter should show selected count")
        }
    }

    func testMultiItemSelectAllButton() throws {
        // Given: User is on multi-item selection view
        navigateToMultiItemSelection()

        // When: User taps "Select All" button
        if multiItemSelectionScreen.isSelectAllButtonVisible() {
            multiItemSelectionScreen.tapSelectAll()

            // Then: All items should be selected
            if let counterText = multiItemSelectionScreen.getSelectionCounterText() {
                let itemCount = multiItemSelectionScreen.getItemCardCount()
                XCTAssertTrue(
                    counterText.contains("\(itemCount) of \(itemCount)"),
                    "All items should be selected")
            }

            // And: "Deselect All" button should appear
            XCTAssertTrue(
                multiItemSelectionScreen.isDeselectAllButtonVisible(),
                "Deselect All button should be visible after selecting all")
        }
    }

    func testMultiItemDeselectAllButton() throws {
        // Given: User has selected all items
        navigateToMultiItemSelection()

        if multiItemSelectionScreen.isSelectAllButtonVisible() {
            multiItemSelectionScreen.tapSelectAll()
        }

        // When: User taps "Deselect All" button
        if multiItemSelectionScreen.isDeselectAllButtonVisible() {
            multiItemSelectionScreen.tapDeselectAll()

            // Then: Selection counter should show 0 selected
            if let counterText = multiItemSelectionScreen.getSelectionCounterText() {
                XCTAssertTrue(
                    counterText.contains("0 of"),
                    "No items should be selected")
            }

            // And: Continue button should be disabled
            XCTAssertFalse(
                multiItemSelectionScreen.isContinueButtonEnabled(),
                "Continue button should be disabled with no selection")
        }
    }

    func testMultiItemSelectionCounter() throws {
        // Given: User is on multi-item selection view
        navigateToMultiItemSelection()

        let itemCount = multiItemSelectionScreen.getItemCardCount()
        guard itemCount > 1 else {
            throw XCTSkip("Need at least 2 items for this test")
        }

        // When: User selects items one by one
        multiItemSelectionScreen.tapItemCard(at: 0)

        // Then: Counter should show correct selection
        if let counterText = multiItemSelectionScreen.getSelectionCounterText() {
            XCTAssertTrue(
                counterText.contains("1 of"),
                "Counter should show 1 item selected")
        }

        // When: User selects another item
        multiItemSelectionScreen.tapItemCard(at: 1)

        // Then: Counter should update
        if let counterText = multiItemSelectionScreen.getSelectionCounterText() {
            XCTAssertTrue(
                counterText.contains("2 of"),
                "Counter should show 2 items selected")
        }
    }

    func testMultiItemLocationPicker() throws {
        // Given: User is on multi-item selection view
        navigateToMultiItemSelection()

        // When: User taps location button
        multiItemSelectionScreen.tapLocationButton()

        // Then: Location picker sheet should appear
        let locationSheet = app.sheets.firstMatch
        XCTAssertTrue(
            locationSheet.waitForExistence(timeout: 3),
            "Location picker sheet should appear")
    }

    func testMultiItemContinueButton() throws {
        // Given: User has selected items
        navigateToMultiItemSelection()

        if multiItemSelectionScreen.isSelectAllButtonVisible() {
            multiItemSelectionScreen.tapSelectAll()
        }

        // When: User taps continue button
        XCTAssertTrue(
            multiItemSelectionScreen.isContinueButtonEnabled(),
            "Continue button should be enabled with selection")

        multiItemSelectionScreen.tapContinue()

        // Then: Should navigate to summary view
        let summaryView = app.otherElements["multiItemSummaryView"]
        XCTAssertTrue(
            summaryView.waitForExistence(timeout: 10),
            "Multi-item summary view should appear")

        // And the items should be visible on the Dashboard under "Recently added"
    }

    func testMultiItemCancelButton() throws {
        // Given: User is on multi-item selection view
        navigateToMultiItemSelection()

        // When: User taps cancel button
        multiItemSelectionScreen.tapCancel()

        // Then: Should return to dashboard
        XCTAssertTrue(
            dashboardScreen.isDisplayed(),
            "Should return to dashboard after cancel")
    }

    func testMultiItemReanalyzeButton() throws {
        // Given: User is on multi-item selection view
        navigateToMultiItemSelection()

        // When: User taps reanalyze button
        multiItemSelectionScreen.tapReanalyze()

        // Then: Should go back to analysis view
        let analysisView = app.otherElements["imageAnalysisView"]
        XCTAssertTrue(
            analysisView.waitForExistence(timeout: 5),
            "Analysis view should appear after reanalyze")
    }

    // MARK: - Helper Methods

    private func openCamera() {
        dashboardScreen.addItemFromCameraButton.tap()
        XCTAssertTrue(
            cameraScreen.waitForCamera(timeout: 5),
            "Camera should open")
    }

    private func switchToMultiMode() {
        let modePicker = app.segmentedControls.firstMatch
        if modePicker.waitForExistence(timeout: 5) {
            let multiButton = modePicker.buttons["Multi"]
            if multiButton.exists && !multiButton.isSelected {
                multiButton.tap()
            }
        }
    }

    private func navigateToMultiItemSelection() {
        // Open camera
        openCamera()

        // Switch to Multi mode
        switchToMultiMode()

        // Capture photo
        cameraScreen.captureButton.tap()

        // Wait for preview overlay
        XCTAssertTrue(
            cameraScreen.waitForPreviewOverlay(),
            "Preview overlay should appear after capture")

        // Continue to analysis
        cameraScreen.doneButton.tap()

        // Wait for analysis to complete and selection view to appear
        XCTAssertTrue(
            multiItemSelectionScreen.waitForAnalysisToComplete(timeout: 15),
            "Should navigate to multi-item selection view")
    }
}
