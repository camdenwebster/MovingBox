import XCTest

@MainActor
final class PhotoButtonVisibilityUITests: XCTestCase {
    var app: XCUIApplication!
    var cameraScreen: CameraScreen!
    var listScreen: InventoryListScreen!
    var detailScreen: InventoryDetailScreen!
    var navigationHelper: NavigationHelper!
    var dashboardScreen: DashboardScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Initialize screen objects
        cameraScreen = CameraScreen(app: app, testCase: self)
        listScreen = InventoryListScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        navigationHelper = NavigationHelper(app: app)
        dashboardScreen = DashboardScreen(app: app)

        setupSnapshot(app)
    }

    override func tearDownWithError() throws {
        app = nil
        listScreen = nil
        detailScreen = nil
        navigationHelper = nil
    }

    // MARK: - Pro User Tests

    func testProUserCanAddFirstPhoto() throws {
        // Given: Pro user with a new item (no photos)
        app.launchArguments = [
            "Is-Pro",
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
            "Disable-Animations"
        ]
        app.launch()
        
        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: User navigates to create a new item manually
        navigationHelper.navigateToAllItems()
        listScreen.openToolbarMenu()
        listScreen.tapCreateManually()

        // Then: Detail view should appear in edit mode
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 5),
                     "Detail view should appear")

        // And: "Add Photo" button should be visible in placeholder (no photos state)
        XCTAssertTrue(detailScreen.waitForAddFirstPhotoButton(),
                     "Add Photo button should be visible for Pro user adding first photo")
    }
    
    func testFreeUserCanAddFirstPhoto() throws {
        // Given: Standard (free) user with a new item (no photos)
        app.launchArguments = [
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
            "Disable-Animations"
        ]
        app.launch()
        
        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: User navigates to create a new item manually
        navigationHelper.navigateToAllItems()
        listScreen.openToolbarMenu()
        listScreen.tapCreateManually()

        // Then: Detail view should appear in edit mode
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 5),
                     "Detail view should appear")

        // And: "Add Photo" button should be visible in placeholder (no photos state)
        XCTAssertTrue(detailScreen.waitForAddFirstPhotoButton(),
                     "Add Photo button should be visible for standard user adding first photo")
    }

    func testProUserCanAddAdditionalPhotosFromCameral() throws {
        // Given: Pro user with an existing item that has at least one photo
        let launchArguments = [
            "Is-Pro",
            "Disable-Persistence",
            "Skip-Onboarding",
            "Use-Test-Data",
            "UI-Testing-Mock-Camera",
            "Disable-Animations"
        ]
        navigationHelper.launchWithArguments(launchArguments)
        
        // When: User navigates to an existing item with a photo and enters edit mode
        navigationHelper.navigateToAnExistingItem()
        
        // Wait for detail view to load and enter edit mode
        detailScreen.enterEditMode()
        
        // Then: Blue + button should be visible for adding additional photos
        XCTAssertTrue(detailScreen.waitForAddAdditionalPhotoButton(),
                      "Blue + button should be visible for Pro user adding additional photos")
        
        // And: the confirmation dialog should display the available photo options when tapped
        detailScreen.addPhotoThumbnailButton.tap()
        XCTAssertTrue(detailScreen.takePhotoButton.isHittable && detailScreen.chooseFromLibraryButton.isHittable && detailScreen.scanDocumentButton.isHittable, "The confirmation dialog should display the available photo options when tapped")
        
        // And: the user should be able to add another photo using the camera
        detailScreen.takePhotoButton.tap()
        cameraScreen.takePhoto()
        
        // And: the label displaying the number of photos should read 1/2
        XCTAssertEqual(detailScreen.photoCountText.label, "1 / 2", "The label displaying the number of photos should read 1/2")
    }

    // MARK: - Free User Tests

    func testFreeUserCannotAddSecondPhoto() throws {
        // Given: Free user (non-Pro) with an existing item that has one photo
        app.launchArguments = [
            "Skip-Onboarding",
            "Disable-Persistence",
            "Use-Test-Data",
            "UI-Testing-Mock-Camera",
            "Disable-Animations"
        ]
        app.launch()
        
        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: User navigates to an existing item with a photo
        navigationHelper.navigateToAllItems()

        XCTAssertTrue(listScreen.allItemsNavigationTitle.waitForExistence(timeout: 5),
                     "All Items list should be visible")

        // Tap on the first item in the list (should have a photo from test data)
        listScreen.tapFirstItem()

        // Wait for detail view to load and enter edit mode
        XCTAssertTrue(detailScreen.editButton.waitForExistence(timeout: 5),
                     "Edit button should be visible")
        detailScreen.editButton.tap()

        // Then: Blue + button should NOT be visible (free tier limit: 1 photo)
        // Wait a moment to ensure UI has fully rendered
        sleep(1)

        XCTAssertFalse(detailScreen.isAddAdditionalPhotoButtonVisible(),
                      "Blue + button should NOT be visible for free user when item already has a photo")
    }
}
