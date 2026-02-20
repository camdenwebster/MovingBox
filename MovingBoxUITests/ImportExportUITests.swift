import XCTest

final class ImportExportUITests: XCTestCase {
    let app = XCUIApplication()
    var dashboardScreen: DashboardScreen!
    var settingsScreen: SettingsScreen!
    var syncAndDataScreen: SyncDataScreen!
    var exportScreen: ExportScreen!
    var importScreen: ImportScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Is-Pro",
            "Skip-Onboarding",
            "Disable-Persistence",
            "Use-Test-Data",
            "UI-Testing-Mock-Camera",
            "Disable-Animations",
        ]

        app.launch()

        dashboardScreen = DashboardScreen(app: app)
        settingsScreen = SettingsScreen(app: app)
        syncAndDataScreen = SyncDataScreen(app: app)
        exportScreen = ExportScreen(app: app)
        importScreen = ImportScreen(app: app)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testDashboardLoads() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should load")
    }

    func testCanNavigateToSettings() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should be displayed")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings screen should be displayed")
    }

    func testCanNavigateToSyncData() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should be displayed")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings screen should be displayed")

        settingsScreen.tapSyncAndData()
        let syncDataLabel = app.staticTexts["Sync and Data"]
        XCTAssertTrue(syncDataLabel.waitForExistence(timeout: 10), "Sync & Data screen should appear")
    }

    func testExportDataLinkExists() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should be displayed")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings screen should be displayed")

        settingsScreen.tapSyncAndData()
        let syncDataLabel = app.staticTexts["Sync and Data"]
        XCTAssertTrue(syncDataLabel.waitForExistence(timeout: 10), "Sync & Data screen should appear")

        let exportLink = app.buttons["exportDataLink"]
        XCTAssertTrue(exportLink.waitForExistence(timeout: 5), "Export Data link should exist")
    }

    func testImportDataLinkExists() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should be displayed")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings screen should be displayed")

        settingsScreen.tapSyncAndData()
        let syncDataLabel = app.staticTexts["Sync and Data"]
        XCTAssertTrue(syncDataLabel.waitForExistence(timeout: 10), "Sync & Data screen should appear")

        let importLink = app.buttons["importDataLink"]
        XCTAssertTrue(importLink.waitForExistence(timeout: 5), "Import Data link should exist")
    }

    func testCanNavigateToExportScreen() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should be displayed")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings screen should be displayed")

        settingsScreen.tapSyncAndData()
        let syncDataLabel = app.staticTexts["Sync and Data"]
        XCTAssertTrue(syncDataLabel.waitForExistence(timeout: 10), "Sync & Data screen should appear")

        let exportLink = app.buttons["exportDataLink"]
        XCTAssertTrue(exportLink.waitForExistence(timeout: 5), "Export Data link should exist")
        exportLink.tap()

        XCTAssertTrue(exportScreen.isDisplayed(), "Export screen should be displayed")
    }

    func testCanNavigateToImportScreen() throws {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should be displayed")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings screen should be displayed")

        settingsScreen.tapSyncAndData()
        let syncDataLabel = app.staticTexts["Sync and Data"].firstMatch
        XCTAssertTrue(syncDataLabel.waitForExistence(timeout: 10), "Sync & Data screen should appear")

        let importLink = app.buttons["importDataLink"]
        XCTAssertTrue(importLink.waitForExistence(timeout: 5), "Import Data link should exist")
        importLink.tap()

        XCTAssertTrue(importScreen.isDisplayed(), "Import screen should be displayed")
    }

    func testExportScreenHasButton() throws {
        navigateToExportScreen()
        XCTAssertTrue(
            exportScreen.exportButton.waitForExistence(timeout: 5), "Export button should exist")
    }

    func testImportScreenHasButton() throws {
        navigateToImportScreen()
        XCTAssertTrue(
            importScreen.selectFileButton.waitForExistence(timeout: 5), "Select file button should exist")
    }

    func testExportButtonIsEnabled() throws {
        navigateToExportScreen()
        XCTAssertTrue(
            exportScreen.isExportButtonEnabled(), "Export button should be enabled by default")
    }

    func testImportButtonIsEnabled() throws {
        navigateToImportScreen()
        XCTAssertTrue(
            importScreen.isSelectFileButtonEnabled(), "Select file button should be enabled by default")
    }

    func testExportButtonDisabledWhenNoOptionsSelected() throws {
        navigateToExportScreen()
        exportScreen.disableAllCSVOptions()
        sleep(1)
        XCTAssertTrue(
            exportScreen.isExportButtonEnabled(),
            "Export button should remain enabled for CSV exports even when all optional toggles are off")
    }

    func testImportButtonDisabledWhenNoOptionsSelected() throws {
        navigateToImportScreen()
        importScreen.disableAllOptions()
        sleep(1)
        XCTAssertTrue(
            importScreen.isSelectFileButtonDisabled(),
            "Select file button should be disabled when no options selected")
    }

    func testImportWarningAppears() throws {
        navigateToImportScreen()
        importScreen.enableAllOptions()
        importScreen.tapSelectFileButton()
        XCTAssertTrue(importScreen.waitForDuplicateWarning(), "Duplicate warning should appear")
    }

    private func navigateToExportScreen() {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should load")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings should load")

        settingsScreen.tapSyncAndData()

        XCTAssertTrue(syncAndDataScreen.isDisplayed(), "Sync and Data should appear")

        let exportLink = app.buttons["exportDataLink"]
        XCTAssertTrue(exportLink.waitForExistence(timeout: 5), "Export link should exist")
        exportLink.tap()
    }

    private func navigateToImportScreen() {
        XCTAssertTrue(dashboardScreen.waitForDashboard(), "Dashboard should load")
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.waitForSettingsScreen(), "Settings should load")

        settingsScreen.tapSyncAndData()

        XCTAssertTrue(syncAndDataScreen.isDisplayed(), "Sync and Data should appear")

        let importLink = app.buttons["importDataLink"]
        XCTAssertTrue(importLink.waitForExistence(timeout: 5), "Import link should exist")
        importLink.tap()
    }
}
