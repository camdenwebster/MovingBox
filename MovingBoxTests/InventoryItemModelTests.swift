import Testing
import Foundation
@testable import MovingBox

@MainActor
@Suite struct InventoryItemModelTests {
    
    @Test("Test item initialization with default values")
    func testDefaultItemInitialization() async throws {
        let item = InventoryItem()
        
        #expect(item.title == "")
        #expect(item.quantityString == "1")
        #expect(item.quantityInt == 1)
        #expect(item.desc == "")
        #expect(item.serial == "")
        #expect(item.model == "")
        #expect(item.make == "")
        #expect(item.price == Decimal.zero)
        #expect(item.insured == false)
        #expect(item.assetId == "")
        #expect(item.notes == "")
        #expect(item.hasUsedAI == false)
    }
    
    @Test("Test item initialization with custom values")
    func testCustomItemInitialization() async throws {
        let testItem = InventoryItem()
        
        testItem.title = "Test Item"
        testItem.quantityString = "1"
        testItem.quantityInt = 1
        testItem.desc = "Test Description"
        testItem.serial = "123ABC"
        testItem.model = "TestModel"
        testItem.make = "TestMake"
        testItem.price = Decimal(string: "99.99")!
        testItem.insured = false
        testItem.assetId = "TEST123"
        testItem.notes = "Test notes"
        
        #expect(testItem.title == "Test Item")
        #expect(testItem.quantityString == "1")
        #expect(testItem.quantityInt == 1)
        #expect(testItem.desc == "Test Description")
        #expect(testItem.serial == "123ABC")
        #expect(testItem.model == "TestModel")
        #expect(testItem.make == "TestMake")
        #expect(testItem.price == Decimal(string: "99.99"))
        #expect(testItem.insured == false)
        #expect(testItem.assetId == "TEST123")
        #expect(testItem.notes == "Test notes")
    }
    
    @Test("Test secondary photos array initialization")
    func testSecondaryPhotosInitialization() async throws {
        let item = InventoryItem()
        
        // Should be initialized as empty array
        #expect(item.secondaryPhotoURLs.isEmpty == true)
        #expect(item.secondaryPhotoURLs.count == 0)
    }
    
    @Test("Test secondary photos array with custom values")
    func testSecondaryPhotosCustomValues() async throws {
        let testURLs = ["url1", "url2", "url3"]
        let item = InventoryItem(
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: nil,
            label: nil,
            price: 0,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false,
            hasUsedAI: false,
            secondaryPhotoURLs: testURLs
        )
        
        #expect(item.secondaryPhotoURLs.count == 3)
        #expect(item.secondaryPhotoURLs == testURLs)
    }
    
    @Test("Test adding secondary photo URLs")
    func testAddSecondaryPhotoURL() async throws {
        let item = InventoryItem()
        
        // Add first URL
        item.addSecondaryPhotoURL("url1")
        #expect(item.secondaryPhotoURLs.count == 1)
        #expect(item.secondaryPhotoURLs.contains("url1"))
        
        // Add second URL
        item.addSecondaryPhotoURL("url2")
        #expect(item.secondaryPhotoURLs.count == 2)
        #expect(item.secondaryPhotoURLs.contains("url2"))
        
        // Try to add duplicate URL (should be ignored)
        item.addSecondaryPhotoURL("url1")
        #expect(item.secondaryPhotoURLs.count == 2)
        
        // Try to add empty URL (should be ignored)
        item.addSecondaryPhotoURL("")
        #expect(item.secondaryPhotoURLs.count == 2)
    }
    
    @Test("Test removing secondary photo URLs")
    func testRemoveSecondaryPhotoURL() async throws {
        let item = InventoryItem()
        
        // Add some URLs
        item.addSecondaryPhotoURL("url1")
        item.addSecondaryPhotoURL("url2")
        item.addSecondaryPhotoURL("url3")
        #expect(item.secondaryPhotoURLs.count == 3)
        
        // Remove middle URL
        item.removeSecondaryPhotoURL("url2")
        #expect(item.secondaryPhotoURLs.count == 2)
        #expect(!item.secondaryPhotoURLs.contains("url2"))
        #expect(item.secondaryPhotoURLs.contains("url1"))
        #expect(item.secondaryPhotoURLs.contains("url3"))
        
        // Try to remove non-existent URL (should be ignored)
        item.removeSecondaryPhotoURL("nonexistent")
        #expect(item.secondaryPhotoURLs.count == 2)
    }
    
    @Test("Test removing secondary photo by index")
    func testRemoveSecondaryPhotoAtIndex() async throws {
        let item = InventoryItem()
        
        // Add some URLs
        item.addSecondaryPhotoURL("url1")
        item.addSecondaryPhotoURL("url2")
        item.addSecondaryPhotoURL("url3")
        #expect(item.secondaryPhotoURLs.count == 3)
        
        // Remove at index 1 (url2)
        item.removeSecondaryPhotoAt(index: 1)
        #expect(item.secondaryPhotoURLs.count == 2)
        #expect(item.secondaryPhotoURLs[0] == "url1")
        #expect(item.secondaryPhotoURLs[1] == "url3")
        
        // Try to remove at invalid index (should be ignored)
        item.removeSecondaryPhotoAt(index: 10)
        #expect(item.secondaryPhotoURLs.count == 2)
        
        item.removeSecondaryPhotoAt(index: -1)
        #expect(item.secondaryPhotoURLs.count == 2)
    }
    
    @Test("Test photo count and validation methods")
    func testPhotoCountMethods() async throws {
        let item = InventoryItem()
        
        // Initially no photos
        #expect(item.getTotalPhotoCount() == 0)
        #expect(item.getSecondaryPhotoCount() == 0)
        #expect(item.hasSecondaryPhotos() == false)
        #expect(item.canAddMorePhotos() == true)
        #expect(item.getRemainingPhotoSlots() == 5)
        
        // Add primary photo
        item.imageURL = URL(string: "primary.jpg")
        #expect(item.getTotalPhotoCount() == 1)
        #expect(item.getSecondaryPhotoCount() == 0)
        #expect(item.canAddMorePhotos() == true)
        #expect(item.getRemainingPhotoSlots() == 4)
        
        // Add secondary photos
        item.addSecondaryPhotoURL("url1")
        item.addSecondaryPhotoURL("url2")
        #expect(item.getTotalPhotoCount() == 3)
        #expect(item.getSecondaryPhotoCount() == 2)
        #expect(item.hasSecondaryPhotos() == true)
        #expect(item.canAddMorePhotos() == true)
        #expect(item.getRemainingPhotoSlots() == 2)
        
        // Add more to reach limit
        item.addSecondaryPhotoURL("url3")
        item.addSecondaryPhotoURL("url4")
        #expect(item.getTotalPhotoCount() == 5)
        #expect(item.getSecondaryPhotoCount() == 4)
        #expect(item.canAddMorePhotos() == false)
        #expect(item.getRemainingPhotoSlots() == 0)
        
        // Try to add beyond limit (should be ignored)
        item.addSecondaryPhotoURL("url5")
        #expect(item.getSecondaryPhotoCount() == 4) // Should remain 4
    }
    
    @Test("Test getting all photo URLs")
    func testGetAllPhotoURLs() async throws {
        let item = InventoryItem()
        
        // No photos
        #expect(item.getAllPhotoURLs().isEmpty)
        
        // Add primary photo only
        item.imageURL = URL(string: "primary.jpg")
        let urlsWithPrimary = item.getAllPhotoURLs()
        #expect(urlsWithPrimary.count == 1)
        #expect(urlsWithPrimary[0] == "primary.jpg")
        
        // Add secondary photos
        item.addSecondaryPhotoURL("secondary1.jpg")
        item.addSecondaryPhotoURL("secondary2.jpg")
        let allUrls = item.getAllPhotoURLs()
        #expect(allUrls.count == 3)
        #expect(allUrls[0] == "primary.jpg") // Primary should be first
        #expect(allUrls.contains("secondary1.jpg"))
        #expect(allUrls.contains("secondary2.jpg"))
    }
    
    @Test("Test clearing all secondary photos")
    func testClearAllSecondaryPhotos() async throws {
        let item = InventoryItem()
        
        // Add some secondary photos
        item.addSecondaryPhotoURL("url1")
        item.addSecondaryPhotoURL("url2")
        item.addSecondaryPhotoURL("url3")
        #expect(item.secondaryPhotoURLs.count == 3)
        
        // Clear all
        item.clearAllSecondaryPhotos()
        #expect(item.secondaryPhotoURLs.isEmpty)
        #expect(item.getSecondaryPhotoCount() == 0)
        #expect(item.hasSecondaryPhotos() == false)
    }
    
    @Test("Test quantity validation with invalid input")
    func testInvalidQuantityValidation() async throws {
        let item = InventoryItem()
        item.quantityString = "abc"
        
        #expect(item.isInteger == false)
        item.validateQuantityInput()
        #expect(item.showInvalidQuantityAlert == true)
        #expect(item.quantityInt == 1) // Should maintain default value
    }
    
    @Test("Test quantity validation with valid input")
    func testValidQuantityValidation() async throws {
        let item = InventoryItem()
        item.quantityString = "5"
        
        #expect(item.isInteger == true)
        item.validateQuantityInput()
        #expect(item.showInvalidQuantityAlert == false)
        #expect(item.quantityInt == 5)
    }
    
    @Test("Test item total value calculation")
    func testItemTotalValue() async throws {
        let testItem = InventoryItem()
        testItem.price = Decimal(string: "99.99")!
        testItem.quantityInt = 3
        
        let expectedTotal = Decimal(string: "299.97")
        #expect(testItem.price * Decimal(testItem.quantityInt) == expectedTotal)
    }
    
    @Test("Test quantity validation")
    func testQuantityValidation() async throws {
        let item = InventoryItem(
            title: "",
            quantityString: "abc",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: nil,
            label: nil,
            price: 0,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )
        
        #expect(item.isInteger == false)
        item.validateQuantityInput()
        #expect(item.showInvalidQuantityAlert == true)
        
        item.quantityString = "5"
        
        #expect(item.isInteger == true)
        item.validateQuantityInput()
        #expect(item.quantityInt == 5)
        #expect(item.showInvalidQuantityAlert == false)
    }
    
    @Test("Test dashboard total value calculation with multiple items")
    func testDashboardTotalValueCalculation() async throws {
        // Create test items with different quantities and prices
        let item1 = InventoryItem()
        item1.price = Decimal(string: "10.00")!
        item1.quantityInt = 2
        
        let item2 = InventoryItem()
        item2.price = Decimal(string: "25.50")!
        item2.quantityInt = 3
        
        let item3 = InventoryItem()
        item3.price = Decimal(string: "100.00")!
        item3.quantityInt = 1
        
        let items = [item1, item2, item3]
        
        // Simulate the dashboard calculation logic
        let totalValue = items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
        
        // Expected: (10.00 * 2) + (25.50 * 3) + (100.00 * 1) = 20.00 + 76.50 + 100.00 = 196.50
        let expectedTotal = Decimal(string: "196.50")!
        #expect(totalValue == expectedTotal)
    }
    
    @Test("Test dashboard total value calculation with single item")
    func testDashboardSingleItemValueCalculation() async throws {
        // Test the example from the issue: 50 forks at $1 each should be $50
        let forks = InventoryItem()
        forks.title = "Forks"
        forks.price = Decimal(string: "1.00")!
        forks.quantityInt = 50
        
        let items = [forks]
        
        // Simulate the dashboard calculation logic
        let totalValue = items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
        
        // Expected: 1.00 * 50 = 50.00
        let expectedTotal = Decimal(string: "50.00")!
        #expect(totalValue == expectedTotal)
    }
    
    @Test("Test dashboard total value calculation with zero quantity")
    func testDashboardZeroQuantityValueCalculation() async throws {
        let item = InventoryItem()
        item.price = Decimal(string: "10.00")!
        item.quantityInt = 0
        
        let items = [item]
        
        // Simulate the dashboard calculation logic
        let totalValue = items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
        
        // Expected: 10.00 * 0 = 0.00
        let expectedTotal = Decimal.zero
        #expect(totalValue == expectedTotal)
    }
    
    @Test("Test location value calculation with multiple items")
    func testLocationValueCalculation() async throws {
        let item1 = InventoryItem()
        item1.price = Decimal(string: "15.00")!
        item1.quantityInt = 2
        
        let item2 = InventoryItem()
        item2.price = Decimal(string: "30.00")!
        item2.quantityInt = 4
        
        let items = [item1, item2]
        
        // Simulate the location calculation logic
        let totalValue = items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
        
        // Expected: (15.00 * 2) + (30.00 * 4) = 30.00 + 120.00 = 150.00
        let expectedTotal = Decimal(string: "150.00")!
        #expect(totalValue == expectedTotal)
    }
    
    @Test("Test label value calculation with multiple items")
    func testLabelValueCalculation() async throws {
        let item1 = InventoryItem()
        item1.price = Decimal(string: "5.00")!
        item1.quantityInt = 10
        
        let item2 = InventoryItem()
        item2.price = Decimal(string: "12.50")!
        item2.quantityInt = 8
        
        let items = [item1, item2]
        
        // Simulate the label calculation logic
        let totalValue = items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
        
        // Expected: (5.00 * 10) + (12.50 * 8) = 50.00 + 100.00 = 150.00
        let expectedTotal = Decimal(string: "150.00")!
        #expect(totalValue == expectedTotal)
    }
    
    @Test("Test effectiveHome computed property")
    func testEffectiveHomeProperty() async throws {
        // Test case 1: Item with location that has a home
        let home1 = Home(name: "Test Home 1")
        let location1 = InventoryLocation(name: "Test Location")
        location1.home = home1
        
        let item1 = InventoryItem()
        item1.location = location1
        
        #expect(item1.effectiveHome === home1, "Item should inherit home from location")
        
        // Test case 2: Item without location but with direct home reference
        let home2 = Home(name: "Test Home 2")
        let item2 = InventoryItem()
        item2.home = home2
        
        #expect(item2.effectiveHome === home2, "Item should use direct home reference when no location")
        
        // Test case 3: Item with both location home and direct home (location takes precedence)
        let home3 = Home(name: "Test Home 3")
        let location3 = InventoryLocation(name: "Test Location 3")
        location3.home = home3
        
        let item3 = InventoryItem()
        item3.location = location3
        item3.home = Home(name: "Different Home") // This should be ignored
        
        #expect(item3.effectiveHome === home3, "Item should prefer location's home over direct home")
        
        // Test case 4: Item without location or home
        let item4 = InventoryItem()
        #expect(item4.effectiveHome == nil, "Item should have no effective home when neither location nor home is set")
    }
}
