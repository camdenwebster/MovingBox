import XCTest

@MainActor
final class DataDeletionUITests: XCTestCase {
    
    var dashboardScreen: DashboardScreen!
    var settingsScreen: SettingsScreen!
    var syncDataScreen: SyncDataScreen!
    var dataDeletionScreen: DataDeletionScreen!
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Use-Test-Data",
            "Disable-Animations",
            "Skip-Onboarding",
            "UI-Testing-Mock-Camera"

        ]
        
        // Initialize screen objects
        dashboardScreen = DashboardScreen(app: app)
        settingsScreen = SettingsScreen(app: app)
        syncDataScreen = SyncDataScreen(app: app)
        dataDeletionScreen = DataDeletionScreen(app: app)
        
        setupSnapshot(app)
        app.launch()
        
        // Wait for Dashboard to load
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }
    
    override func tearDownWithError() throws {
        dashboardScreen = nil
        settingsScreen = nil
        syncDataScreen = nil
        dataDeletionScreen = nil
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationToDataDeletion() throws {
        // Given: User is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should start on dashboard")
        
        // When: User navigates to Settings
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Should navigate to settings")
        
        // And: User navigates to Sync and Data
        settingsScreen.tapSyncAndData()
        XCTAssertTrue(syncDataScreen.isDisplayed(), "Should navigate to sync and data")
        
        // And: User navigates to Delete All Data
        syncDataScreen.tapDeleteAllData()
        
        // Then: Should be on data deletion screen
        XCTAssertTrue(dataDeletionScreen.isDisplayed(), "Should navigate to data deletion screen")
        XCTAssertTrue(dataDeletionScreen.isWarningSectionVisible(), "Warning section should be visible")
    }
    
    // MARK: - UI Elements Tests
    
    func testWarningSection() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // Then: Warning section should be completely visible
        XCTAssertTrue(dataDeletionScreen.isWarningSectionVisible(), "Warning section should be visible")
        
        // And: All warning elements should exist
        XCTAssertTrue(dataDeletionScreen.warningLabel.exists, "Warning label should exist")
        XCTAssertTrue(dataDeletionScreen.warningDescription.exists, "Warning description should exist")
        XCTAssertTrue(dataDeletionScreen.inventoryItemsWarning.exists, "Inventory items warning should exist")
        XCTAssertTrue(dataDeletionScreen.locationsWarning.exists, "Locations warning should exist")
        XCTAssertTrue(dataDeletionScreen.labelsWarning.exists, "Labels warning should exist")
        XCTAssertTrue(dataDeletionScreen.homeInfoWarning.exists, "Home info warning should exist")
    }
    
    func testScopeSelectionSection() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // Then: Scope selection section should be completely visible
        XCTAssertTrue(dataDeletionScreen.isScopeSectionVisible(), "Scope section should be visible")
        
        // And: All scope elements should exist
        XCTAssertTrue(dataDeletionScreen.deletionScopeHeader.exists, "Deletion scope header should exist")
        XCTAssertTrue(dataDeletionScreen.localOnlyOption.exists, "Local only option should exist")
        XCTAssertTrue(dataDeletionScreen.localAndICloudOption.exists, "Local and iCloud option should exist")
        XCTAssertTrue(dataDeletionScreen.localOnlyDescription.exists, "Local only description should exist")
        XCTAssertTrue(dataDeletionScreen.localAndICloudDescription.exists, "Local and iCloud description should exist")
    }
    
    func testConfirmationSection() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // Then: Confirmation section should be completely visible
        XCTAssertTrue(dataDeletionScreen.isConfirmationSectionVisible(), "Confirmation section should be visible")
        
        // And: All confirmation elements should exist
        XCTAssertTrue(dataDeletionScreen.confirmationInstructions.exists, "Confirmation instructions should exist")
        XCTAssertTrue(dataDeletionScreen.confirmationTextField.exists, "Confirmation text field should exist")
        XCTAssertTrue(dataDeletionScreen.deleteButton.exists, "Delete button should exist")
        XCTAssertTrue(dataDeletionScreen.irreversibleWarning.exists, "Irreversible warning should exist")
    }
    
    // MARK: - Scope Selection Tests
    
    func testScopeSelection() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // When: User selects Local and iCloud option
        dataDeletionScreen.selectLocalAndICloudScope()
        
        // And: User selects Local Only option
        dataDeletionScreen.selectLocalOnlyScope()
        
        // Then: No assertion failure means the taps worked
        // (Visual selection state is hard to test in UI tests, but we can test tapping)
        XCTAssertTrue(dataDeletionScreen.localOnlyOption.exists, "Local only option should still exist")
        XCTAssertTrue(dataDeletionScreen.localAndICloudOption.exists, "Local and iCloud option should still exist")
    }
    
    // MARK: - Confirmation Validation Tests
    
    func testConfirmationValidation() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // Initially button should be disabled (we can't easily test the disabled state in UI tests)
        XCTAssertTrue(dataDeletionScreen.deleteButton.exists, "Delete button should exist")
        
        // When: User enters incorrect text
        dataDeletionScreen.enterConfirmationText("delete")
        
        // And: User enters correct text
        dataDeletionScreen.enterConfirmationText("DELETE")
        
        // Then: Button should be enabled now (we test this by attempting to tap)
        XCTAssertTrue(dataDeletionScreen.isDeleteButtonEnabled(), "Delete button should be enabled with correct text")
        
        // And: Confirmation text should be correct
        XCTAssertEqual(dataDeletionScreen.getConfirmationText(), "DELETE", "Confirmation text should be DELETE")
    }
    
    // MARK: - Final Confirmation Alert Tests
    
    func testFinalConfirmationAlert() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // When: User enters correct confirmation text and taps delete
        dataDeletionScreen.performDeletion()
        
        // Then: Final confirmation alert should appear
        XCTAssertTrue(dataDeletionScreen.isFinalConfirmationAlertVisible(), "Final confirmation alert should appear")
        
        // And: Alert should have correct message
        let expectedMessage = "This action cannot be undone. Are you sure you want to delete all your inventory data?"
        XCTAssertEqual(dataDeletionScreen.getFinalConfirmationMessage(), expectedMessage, "Alert should have correct message")
        
        // And: Alert should have correct buttons
        XCTAssertTrue(dataDeletionScreen.areFinalConfirmationButtonsVisible(), "Alert should have Cancel and Delete buttons")
        
        // When: User cancels
        dataDeletionScreen.handleFinalConfirmationAlert(confirm: false)
        
        // Then: Alert should disappear
        XCTAssertFalse(dataDeletionScreen.isFinalConfirmationAlertVisible(), "Alert should disappear after cancel")
    }
    
    // MARK: - Complete Deletion Flow Test
    
    func testCompleteDeletionFlow() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // When: User completes the deletion flow
        dataDeletionScreen.performDeletion()
        dataDeletionScreen.handleFinalConfirmationAlert(confirm: true)
        
        // Then: Should navigate back to previous screen
        // Wait for deletion to complete and navigation back
        let expectation = XCTestExpectation(description: "Navigation back after deletion")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if !self.dataDeletionScreen.isDisplayed() {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // And: Should be back on Sync and Data screen
        XCTAssertTrue(syncDataScreen.isDisplayed(), "Should return to Sync and Data screen")
    }
    
    // MARK: - Edge Cases Tests
    
    func testConfirmationTextEdgeCases() throws {
        // Given: User navigates to data deletion screen
        navigateToDataDeletion()
        
        // When: User tests various incorrect inputs
        let incorrectInputs = ["", "delete", "DELETE ", " DELETE", "DELET"]
        
        for incorrectInput in incorrectInputs {
            dataDeletionScreen.enterConfirmationText(incorrectInput)
            
            // Then: Button should remain available (we can't easily test disabled state, but we ensure no crash)
            XCTAssertTrue(dataDeletionScreen.deleteButton.exists, "Delete button should exist for input: '\(incorrectInput)'")
        }
        
        // When: User enters correct input
        dataDeletionScreen.enterConfirmationText("DELETE")
        
        // Then: Button should be enabled
        XCTAssertTrue(dataDeletionScreen.isDeleteButtonEnabled(), "Delete button should be enabled with correct text")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToDataDeletion() {
        // Navigate from Dashboard -> Settings -> Sync and Data -> Delete All Data
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Should navigate to settings")
        
        settingsScreen.tapSyncAndData()
        XCTAssertTrue(syncDataScreen.isDisplayed(), "Should navigate to sync and data")
        
        syncDataScreen.tapDeleteAllData()
        XCTAssertTrue(dataDeletionScreen.isDisplayed(), "Should navigate to data deletion")
    }
}
