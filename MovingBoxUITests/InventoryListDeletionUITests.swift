import XCTest

final class InventoryListDeletionUITests: XCTestCase {
    var app: XCUIApplication!
    var dashboardScreen: DashboardScreen!
    var inventoryListScreen: InventoryListScreen!
    var navigationHelper: NavigationHelper!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        dashboardScreen = DashboardScreen(app: app)
        inventoryListScreen = InventoryListScreen(app: app)
        navigationHelper = NavigationHelper(app: app)
        
        app.launchArguments = ["Use-Test-Data", "Disable-Animations"]
        app.launch()
        
        // Navigate to All Items view
        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
        navigationHelper.navigateToAllItems()
        
        // Wait for items to load
        XCTAssertTrue(inventoryListScreen.waitForItemsToLoad(), "Items should load within timeout")
    }
    
    override func tearDownWithError() throws {
        app = nil
        inventoryListScreen = nil
        dashboardScreen = nil
        navigationHelper = nil
    }
    
    func testEnterAndExitSelectionMode() throws {
        // Given: We are on the inventory list view
        XCTAssertFalse(inventoryListScreen.isSelectionModeActive(), "Selection mode should not be active initially")
        
        // When: We enter selection mode
        inventoryListScreen.enterSelectionMode()
        
        // Then: Selection mode should be active
        XCTAssertTrue(inventoryListScreen.isSelectionModeActive(), "Selection mode should be active after entering")
        
        // When: We exit selection mode
        inventoryListScreen.exitSelectionMode()
        
        // Then: Selection mode should be inactive
        XCTAssertFalse(inventoryListScreen.isSelectionModeActive(), "Selection mode should be inactive after exiting")
    }
    
    func testSelectAndDeleteSingleItem() throws {
        // Given: We have items in the list
        let initialItemCount = inventoryListScreen.getItemCount()
        XCTAssertGreaterThan(initialItemCount, 0, "Should have items to test deletion")
        
        // When: We enter selection mode
        inventoryListScreen.enterSelectionMode()
        XCTAssertTrue(inventoryListScreen.isSelectionModeActive(), "Selection mode should be active")
        
        // And: We select the first item
        inventoryListScreen.selectItem(at: 0)
        
        // And: We trigger deletion
        inventoryListScreen.deleteSelectedItems()
        
        // Then: Delete confirmation alert should appear
        XCTAssertTrue(inventoryListScreen.waitForDeleteConfirmationAlert(), "Delete confirmation alert should appear")
        
        // When: We confirm deletion
        inventoryListScreen.confirmDeletion()
        
        // Then: Item should be deleted and count should decrease
        let finalItemCount = inventoryListScreen.getItemCount()
        XCTAssertEqual(finalItemCount, initialItemCount - 1, "Item count should decrease by 1 after deletion")
        
        // And: Selection mode should exit automatically
        XCTAssertFalse(inventoryListScreen.isSelectionModeActive(), "Selection mode should exit after deletion")
    }
    
    func testSelectAndDeleteMultipleItems() throws {
        // Given: We have multiple items in the list
        let initialItemCount = inventoryListScreen.getItemCount()
        XCTAssertGreaterThan(initialItemCount, 2, "Should have at least 3 items to test multiple deletion")
        
        // When: We enter selection mode
        inventoryListScreen.enterSelectionMode()
        XCTAssertTrue(inventoryListScreen.isSelectionModeActive(), "Selection mode should be active")
        
        // And: We select multiple items (first two items)
        inventoryListScreen.selectMultipleItems(indices: [0, 1])
        
        // And: We trigger deletion
        inventoryListScreen.deleteSelectedItems()
        
        // Then: Delete confirmation alert should appear
        XCTAssertTrue(inventoryListScreen.waitForDeleteConfirmationAlert(), "Delete confirmation alert should appear")
        
        // And: The alert should mention multiple items
        let alertMessage = inventoryListScreen.deleteConfirmationAlert.staticTexts.element(boundBy: 1).label
        XCTAssertTrue(alertMessage.contains("2 items"), "Alert should mention deleting 2 items")
        
        // When: We confirm deletion
        inventoryListScreen.confirmDeletion()
        
        // Then: Items should be deleted and count should decrease by 2
        let finalItemCount = inventoryListScreen.getItemCount()
        XCTAssertEqual(finalItemCount, initialItemCount - 2, "Item count should decrease by 2 after deletion")
        
        // And: Selection mode should exit automatically
        XCTAssertFalse(inventoryListScreen.isSelectionModeActive(), "Selection mode should exit after deletion")
    }
    
    func testCancelDeletion() throws {
        // Given: We have items in the list
        let initialItemCount = inventoryListScreen.getItemCount()
        XCTAssertGreaterThan(initialItemCount, 0, "Should have items to test cancellation")
        
        // When: We enter selection mode and select an item
        inventoryListScreen.enterSelectionMode()
        inventoryListScreen.selectItem(at: 0)
        
        // And: We trigger deletion
        inventoryListScreen.deleteSelectedItems()
        
        // Then: Delete confirmation alert should appear
        XCTAssertTrue(inventoryListScreen.waitForDeleteConfirmationAlert(), "Delete confirmation alert should appear")
        
        // When: We cancel deletion
        inventoryListScreen.cancelDeletion()
        
        // Then: No items should be deleted
        let finalItemCount = inventoryListScreen.getItemCount()
        XCTAssertEqual(finalItemCount, initialItemCount, "Item count should remain the same after canceling deletion")
        
        // And: We should still be in selection mode
        XCTAssertTrue(inventoryListScreen.isSelectionModeActive(), "Selection mode should remain active after canceling deletion")
    }
    
    func testDeleteAllItemsInView() throws {
        // Given: We have a manageable number of items (limit test to prevent long execution)
        let initialItemCount = inventoryListScreen.getItemCount()
        guard initialItemCount <= 10 else {
            throw XCTSkip("Skipping test with too many items to avoid long execution time")
        }
        
        XCTAssertGreaterThan(initialItemCount, 0, "Should have items to test deletion")
        
        // When: We enter selection mode
        inventoryListScreen.enterSelectionMode()
        
        // And: We select all visible items
        let indicesToSelect = Array(0..<initialItemCount)
        inventoryListScreen.selectMultipleItems(indices: indicesToSelect)
        
        // And: We trigger deletion
        inventoryListScreen.deleteSelectedItems()
        
        // Then: Delete confirmation alert should appear
        XCTAssertTrue(inventoryListScreen.waitForDeleteConfirmationAlert(), "Delete confirmation alert should appear")
        
        // When: We confirm deletion
        inventoryListScreen.confirmDeletion()
        
        // Then: All items should be deleted
        let finalItemCount = inventoryListScreen.getItemCount()
        XCTAssertEqual(finalItemCount, 0, "All items should be deleted")
        
        // And: Selection mode should exit automatically
        XCTAssertFalse(inventoryListScreen.isSelectionModeActive(), "Selection mode should exit after deletion")
    }
    
    func testDeleteWithNoItemsSelected() throws {
        // Given: We are in selection mode with no items selected
        inventoryListScreen.enterSelectionMode()
        XCTAssertTrue(inventoryListScreen.isSelectionModeActive(), "Selection mode should be active")
        
        // When: We try to access the actions menu (should be enabled but delete should be disabled)
        inventoryListScreen.actionsButton.tap()
        
        // Then: The delete button should be disabled (not interactable)
        // Note: In SwiftUI, disabled buttons may still exist but not be hittable
        let deleteButton = inventoryListScreen.deleteSelectedButton
        XCTAssertFalse(deleteButton.isHittable, "Delete button should be disabled when no items are selected")
        
        // Clean up by dismissing the menu
        inventoryListScreen.actionsButton.tap() // Tap again to close menu
    }
}
