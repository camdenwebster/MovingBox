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
        #expect(item.aiAnalysisCount == 0)
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
    
    // MARK: - AI Analysis Tracking Tests
    
    @Test("Test AI analysis count initialization")
    func testAiAnalysisCountInitialization() async throws {
        let item = InventoryItem()
        
        // Should start at 0
        #expect(item.aiAnalysisCount == 0)
        #expect(item.hasUsedAI == false)
    }
    
    @Test("Test AI analysis count tracking")
    func testAiAnalysisCountTracking() async throws {
        let item = InventoryItem()
        
        // Simulate first AI analysis
        item.hasUsedAI = true
        item.aiAnalysisCount = 1
        
        #expect(item.hasUsedAI == true)
        #expect(item.aiAnalysisCount == 1)
        
        // Simulate subsequent analyses
        item.aiAnalysisCount = 2
        #expect(item.aiAnalysisCount == 2)
        
        item.aiAnalysisCount = 3
        #expect(item.aiAnalysisCount == 3)
    }
    
    @Test("Test AI analysis count with custom initialization")
    func testAiAnalysisCountCustomInit() async throws {
        let item = InventoryItem(
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "Test",
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
            hasUsedAI: true,
            aiAnalysisCount: 5
        )
        
        #expect(item.hasUsedAI == true)
        #expect(item.aiAnalysisCount == 5)
    }
}
