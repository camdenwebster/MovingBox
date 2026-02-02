import Foundation
import Testing

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
            labels: [],
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
        #expect(item.getSecondaryPhotoCount() == 4)  // Should remain 4
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
        #expect(allUrls[0] == "primary.jpg")  // Primary should be first
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
        #expect(item.quantityInt == 1)  // Should maintain default value
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
            labels: [],
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
        item3.home = Home(name: "Different Home")  // This should be ignored

        #expect(item3.effectiveHome === home3, "Item should prefer location's home over direct home")

        // Test case 4: Item without location or home
        let item4 = InventoryItem()
        #expect(item4.effectiveHome == nil, "Item should have no effective home when neither location nor home is set")
    }

    @Test("Test effectiveHome with location that has nil home falls back to direct home")
    func testEffectiveHomeLocationWithNilHome() async throws {
        // Location exists but has no home assigned
        let location = InventoryLocation(name: "Orphaned Location")
        // location.home is nil by default

        let directHome = Home(name: "Direct Home")

        let item = InventoryItem()
        item.location = location
        item.home = directHome

        // Since location.home is nil, effectiveHome should fall back to item.home
        #expect(item.effectiveHome === directHome, "Item should fall back to direct home when location's home is nil")
    }

    @Test("Test item ID is set correctly on initialization")
    func testItemIdInitialization() async throws {
        // Test default init
        let item1 = InventoryItem()
        #expect(item1.id != UUID(), "Item should have a valid UUID")

        // Test init with title
        let item2 = InventoryItem(title: "Test Item")
        #expect(item2.id != UUID(), "Item should have a valid UUID")

        // Verify IDs are unique
        #expect(item1.id != item2.id, "Different items should have different IDs")
    }

    @Test("Test item ID can be explicitly set")
    func testItemIdExplicitSet() async throws {
        let explicitId = UUID()
        let item = InventoryItem(id: explicitId)

        #expect(item.id == explicitId, "Item ID should match explicitly set UUID")
    }

    @Test("Test home ID is set correctly on initialization")
    func testHomeIdInitialization() async throws {
        let home = Home(name: "Test Home")
        #expect(home.id != UUID(), "Home should have a valid UUID")

        // Test with explicit ID
        let explicitId = UUID()
        let homeWithId = Home(id: explicitId, name: "Home With ID")
        #expect(homeWithId.id == explicitId, "Home ID should match explicitly set UUID")
    }

    @Test("Test location ID is set correctly on initialization")
    func testLocationIdInitialization() async throws {
        let location = InventoryLocation(name: "Test Location")
        #expect(location.id != UUID(), "Location should have a valid UUID")

        // Test with explicit ID
        let explicitId = UUID()
        let locationWithId = InventoryLocation(id: explicitId, name: "Location With ID")
        #expect(locationWithId.id == explicitId, "Location ID should match explicitly set UUID")
    }

    @Test("Test label ID is set correctly on initialization")
    func testLabelIdInitialization() async throws {
        let label = InventoryLabel(name: "Test Label")
        #expect(label.id != UUID(), "Label should have a valid UUID")

        // Test with explicit ID
        let explicitId = UUID()
        let labelWithId = InventoryLabel(id: explicitId, name: "Label With ID")
        #expect(labelWithId.id == explicitId, "Label ID should match explicitly set UUID")
    }

    @Test("Test item home assignment does not affect location")
    func testHomeAssignmentIndependentOfLocation() async throws {
        let home1 = Home(name: "Home 1")
        let home2 = Home(name: "Home 2")
        let location = InventoryLocation(name: "Test Location")
        location.home = home1

        let item = InventoryItem()
        item.location = location
        item.home = home2

        // Verify location's home is unchanged
        #expect(location.home === home1, "Setting item.home should not affect location.home")

        // Verify effectiveHome still uses location's home
        #expect(item.effectiveHome === home1, "effectiveHome should still prefer location's home")
    }

    @Test("Test clearing location makes item use direct home")
    func testClearingLocationUsesDirectHome() async throws {
        let locationHome = Home(name: "Location Home")
        let directHome = Home(name: "Direct Home")
        let location = InventoryLocation(name: "Test Location")
        location.home = locationHome

        let item = InventoryItem()
        item.location = location
        item.home = directHome

        // Initially uses location's home
        #expect(item.effectiveHome === locationHome)

        // Clear location
        item.location = nil

        // Now should use direct home
        #expect(item.effectiveHome === directHome, "After clearing location, item should use direct home")
    }

    // MARK: - Multi-Label Tests

    @Test("Test labels array initialization is empty by default")
    func testLabelsArrayDefaultInitialization() async throws {
        let item = InventoryItem()

        #expect(item.labels.isEmpty, "Labels array should be empty by default")
        #expect(item.labels.count == 0)
    }

    @Test("Test item initialization with single label")
    func testItemInitializationWithSingleLabel() async throws {
        let label = InventoryLabel(name: "Electronics", emoji: "📱")
        let item = InventoryItem(
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: nil,
            labels: [label],
            price: 0,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )

        #expect(item.labels.count == 1)
        #expect(item.labels.first?.name == "Electronics")
        #expect(item.labels.first?.emoji == "📱")
    }

    @Test("Test item initialization with multiple labels")
    func testItemInitializationWithMultipleLabels() async throws {
        let label1 = InventoryLabel(name: "Electronics", emoji: "📱")
        let label2 = InventoryLabel(name: "Office", emoji: "💼")
        let label3 = InventoryLabel(name: "Expensive", emoji: "💰")

        let item = InventoryItem(
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: nil,
            labels: [label1, label2, label3],
            price: 0,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )

        #expect(item.labels.count == 3)
        #expect(item.labels.contains { $0.name == "Electronics" })
        #expect(item.labels.contains { $0.name == "Office" })
        #expect(item.labels.contains { $0.name == "Expensive" })
    }

    @Test("Test adding labels to item")
    func testAddingLabelsToItem() async throws {
        let item = InventoryItem()
        let label1 = InventoryLabel(name: "Electronics", emoji: "📱")
        let label2 = InventoryLabel(name: "Office", emoji: "💼")

        // Initially empty
        #expect(item.labels.isEmpty)

        // Add first label
        item.labels.append(label1)
        #expect(item.labels.count == 1)

        // Add second label
        item.labels.append(label2)
        #expect(item.labels.count == 2)
    }

    @Test("Test removing labels from item")
    func testRemovingLabelsFromItem() async throws {
        let label1 = InventoryLabel(name: "Electronics", emoji: "📱")
        let label2 = InventoryLabel(name: "Office", emoji: "💼")
        let label3 = InventoryLabel(name: "Expensive", emoji: "💰")

        let item = InventoryItem()
        item.labels = [label1, label2, label3]
        #expect(item.labels.count == 3)

        // Remove by ID
        item.labels.removeAll { $0.id == label2.id }
        #expect(item.labels.count == 2)
        #expect(!item.labels.contains { $0.name == "Office" })
        #expect(item.labels.contains { $0.name == "Electronics" })
        #expect(item.labels.contains { $0.name == "Expensive" })
    }

    @Test("Test clearing all labels")
    func testClearingAllLabels() async throws {
        let label1 = InventoryLabel(name: "Electronics", emoji: "📱")
        let label2 = InventoryLabel(name: "Office", emoji: "💼")

        let item = InventoryItem()
        item.labels = [label1, label2]
        #expect(item.labels.count == 2)

        // Clear all labels
        item.labels.removeAll()
        #expect(item.labels.isEmpty)
    }

    @Test("Test maximum 5 labels enforcement in Builder pattern")
    func testBuilderMaxLabelsEnforcement() async throws {
        let labels = (1...10).map { InventoryLabel(name: "Label \($0)", emoji: "🏷️") }

        let item = InventoryItem.Builder(title: "Test Item")
            .addLabel(labels[0])
            .addLabel(labels[1])
            .addLabel(labels[2])
            .addLabel(labels[3])
            .addLabel(labels[4])
            .addLabel(labels[5])  // Should be ignored (6th label)
            .addLabel(labels[6])  // Should be ignored (7th label)
            .build()

        #expect(item.labels.count == 5, "Builder should enforce maximum of 5 labels")
    }

    @Test("Test Builder addLabel prevents duplicates")
    func testBuilderAddLabelPreventsDuplicates() async throws {
        let label = InventoryLabel(name: "Electronics", emoji: "📱")

        let item = InventoryItem.Builder(title: "Test Item")
            .addLabel(label)
            .addLabel(label)  // Same label again
            .addLabel(label)  // Same label again
            .build()

        #expect(item.labels.count == 1, "Builder should prevent duplicate labels")
    }

    @Test("Test Builder labels method sets array directly")
    func testBuilderLabelsMethod() async throws {
        let label1 = InventoryLabel(name: "Electronics", emoji: "📱")
        let label2 = InventoryLabel(name: "Office", emoji: "💼")

        let item = InventoryItem.Builder(title: "Test Item")
            .labels([label1, label2])
            .build()

        #expect(item.labels.count == 2)
        #expect(item.labels.contains { $0.name == "Electronics" })
        #expect(item.labels.contains { $0.name == "Office" })
    }

    @Test("Test replacing labels array")
    func testReplacingLabelsArray() async throws {
        let label1 = InventoryLabel(name: "Old Label", emoji: "📦")
        let label2 = InventoryLabel(name: "New Label 1", emoji: "🏷️")
        let label3 = InventoryLabel(name: "New Label 2", emoji: "✨")

        let item = InventoryItem()
        item.labels = [label1]
        #expect(item.labels.count == 1)

        // Replace with new labels (batch operation behavior)
        item.labels = [label2, label3]
        #expect(item.labels.count == 2)
        #expect(!item.labels.contains { $0.name == "Old Label" })
        #expect(item.labels.contains { $0.name == "New Label 1" })
        #expect(item.labels.contains { $0.name == "New Label 2" })
    }
}

// MARK: - ImageDetails Multi-Category Tests

@MainActor
@Suite struct ImageDetailsMultiCategoryTests {

    @Test("Test ImageDetails with single category backwards compatibility")
    func testImageDetailsSingleCategory() async throws {
        let details = ImageDetails(
            title: "Test Item",
            quantity: "1",
            description: "Test description",
            make: "Test Make",
            model: "Test Model",
            category: "Electronics",
            location: "Office",
            price: "$99.99",
            serialNumber: "123ABC"
        )

        #expect(details.category == "Electronics")
        #expect(details.categories.count == 1)
        #expect(details.categories.first == "Electronics")
    }

    @Test("Test ImageDetails with multiple categories")
    func testImageDetailsMultipleCategories() async throws {
        let details = ImageDetails(
            title: "Test Item",
            quantity: "1",
            description: "Test description",
            make: "Test Make",
            model: "Test Model",
            category: "Electronics",
            categories: ["Electronics", "Office", "Expensive"],
            location: "Office",
            price: "$99.99",
            serialNumber: "123ABC"
        )

        #expect(details.categories.count == 3)
        #expect(details.categories.contains("Electronics"))
        #expect(details.categories.contains("Office"))
        #expect(details.categories.contains("Expensive"))
    }

    @Test("Test ImageDetails empty categories uses single category")
    func testImageDetailsEmptyCategoriesUsesSingleCategory() async throws {
        let details = ImageDetails(
            title: "Test Item",
            quantity: "1",
            description: "Test description",
            make: "Test Make",
            model: "Test Model",
            category: "Furniture",
            categories: [],
            location: "Living Room",
            price: "$199.99",
            serialNumber: ""
        )

        #expect(details.categories.count == 1)
        #expect(details.categories.first == "Furniture")
    }

    @Test("Test ImageDetails empty() has empty categories")
    func testImageDetailsEmptyHasEmptyCategories() async throws {
        let details = ImageDetails.empty()

        #expect(details.categories.isEmpty)
        #expect(details.category == "None")
    }
}
