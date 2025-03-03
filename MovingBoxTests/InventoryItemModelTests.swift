import Testing
import Foundation
@testable import MovingBox

@Suite struct InventoryItemModelTests {
    @Test("Test item initialization")
    func testItemInitialization() async throws {
        let testItem = InventoryItem(
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "Test Description",
            serial: "123ABC",
            model: "TestModel",
            make: "TestMake",
            location: nil,
            label: nil,
            price: 99.99,
            insured: false,
            assetId: "TEST123",
            notes: "Test notes",
            showInvalidQuantityAlert: false
        )
        
        #expect(testItem.title == "Test Item")
        #expect(testItem.quantityString == "1")
        #expect(testItem.quantityInt == 1)
        #expect(testItem.desc == "Test Description")
        #expect(testItem.serial == "123ABC")
        #expect(testItem.model == "TestModel")
        #expect(testItem.make == "TestMake")
        #expect(testItem.price == 99.99)
        #expect(testItem.insured == false)
        #expect(testItem.assetId == "TEST123")
        #expect(testItem.notes == "Test notes")
    }
    
    @Test("Test item total value calculation")
    func testItemTotalValue() async throws {
        let testItem = InventoryItem(
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "Test Description",
            serial: "123ABC",
            model: "TestModel",
            make: "TestMake",
            location: nil,
            label: nil,
            price: Decimal(string: "99.99")!,
            insured: false,
            assetId: "TEST123",
            notes: "Test notes",
            showInvalidQuantityAlert: false
        )
        
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
}
