//
//  CustomFieldTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 8/20/25.
//

import Testing
import SwiftData
@testable import MovingBox

struct CustomFieldTests {
    
    let testContainer: ModelContainer
    let testContext: ModelContext
    
    init() throws {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            CustomField.self,
            CustomFieldValue.self
        ])
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: schema, configurations: [config])
        testContext = ModelContext(testContainer)
    }
    
    // MARK: - CustomField Model Tests
    
    @Test func testCustomFieldCreation() throws {
        // Test basic field creation
        let field = CustomField(
            name: "Test Field",
            fieldDescription: "A test field",
            fieldType: .string,
            scope: .global
        )
        
        #expect(field.name == "Test Field")
        #expect(field.fieldDescription == "A test field")
        #expect(field.fieldType == .string)
        #expect(field.scope == .global)
        #expect(field.scopeId == nil)
        #expect(field.isRequired == false)
        #expect(field.pickerOptions.isEmpty)
    }
    
    @Test func testCustomFieldEnums() throws {
        // Test CustomFieldType enum
        #expect(CustomFieldType.boolean.displayName == "Yes/No")
        #expect(CustomFieldType.string.displayName == "Text")
        #expect(CustomFieldType.decimal.displayName == "Number")
        #expect(CustomFieldType.picker.displayName == "Multiple Choice")
        
        // Test pro-only restrictions
        #expect(CustomFieldType.boolean.isProOnly == false)
        #expect(CustomFieldType.string.isProOnly == false)
        #expect(CustomFieldType.decimal.isProOnly == true)
        #expect(CustomFieldType.picker.isProOnly == true)
        
        // Test CustomFieldScope enum
        #expect(CustomFieldScope.global.displayName == "All Items")
        #expect(CustomFieldScope.label.displayName == "Specific Label")
        #expect(CustomFieldScope.location.displayName == "Specific Location")
    }
    
    @Test func testPickerFieldOptions() throws {
        let field = CustomField(
            name: "Condition",
            fieldType: .picker,
            pickerOptions: ["Mint", "Good", "Fair", "Poor"]
        )
        
        #expect(field.isPickerType == true)
        #expect(field.hasPickerOptions == true)
        #expect(field.pickerOptions.count == 4)
        #expect(field.pickerOptions.contains("Mint"))
        #expect(field.validatePickerValue("Good") == true)
        #expect(field.validatePickerValue("Invalid") == false)
    }
    
    @Test func testFieldAvailability() throws {
        // Create test data
        let label = InventoryLabel(name: "Electronics")
        let location = InventoryLocation(name: "Living Room")
        let item = InventoryItem()
        item.label = label
        item.location = location
        
        testContext.insert(label)
        testContext.insert(location)
        testContext.insert(item)
        
        // Create fields with different scopes
        let globalField = CustomField(name: "Global Field", scope: .global)
        let labelField = CustomField(name: "Label Field", scope: .label, scopeId: label.id.uuidString)
        let locationField = CustomField(name: "Location Field", scope: .location, scopeId: location.id.uuidString)
        let otherLabelField = CustomField(name: "Other Label Field", scope: .label, scopeId: UUID().uuidString)
        
        // Test availability
        #expect(globalField.isAvailableFor(item: item) == true)
        #expect(labelField.isAvailableFor(item: item) == true)
        #expect(locationField.isAvailableFor(item: item) == true)
        #expect(otherLabelField.isAvailableFor(item: item) == false)
    }
    
    // MARK: - CustomFieldValue Model Tests
    
    @Test func testCustomFieldValueCreation() throws {
        let field = CustomField(name: "Test Field", fieldType: .string)
        let item = InventoryItem()
        
        let value = CustomFieldValue(customField: field, inventoryItem: item)
        
        #expect(value.customField?.id == field.id)
        #expect(value.inventoryItem?.id == item.id)
        #expect(value.hasValue == false)
        #expect(value.isEmpty == true)
    }
    
    @Test func testStringValueStorage() throws {
        let field = CustomField(name: "Notes", fieldType: .string)
        let value = CustomFieldValue()
        
        value.setValue("Test string value", for: .string)
        
        #expect(value.stringValue == "Test string value")
        #expect(value.boolValue == nil)
        #expect(value.decimalValue == nil)
        #expect(value.hasValue == true)
        #expect(value.isEmpty == false)
        #expect(value.getDisplayValue() == "Test string value")
    }
    
    @Test func testBooleanValueStorage() throws {
        let value = CustomFieldValue()
        
        value.setValue(true, for: .boolean)
        
        #expect(value.boolValue == true)
        #expect(value.stringValue == nil)
        #expect(value.decimalValue == nil)
        #expect(value.getDisplayValue() == "Yes")
        
        value.setValue(false, for: .boolean)
        #expect(value.getDisplayValue() == "No")
    }
    
    @Test func testDecimalValueStorage() throws {
        let value = CustomFieldValue()
        let testDecimal = Decimal(123.45)
        
        value.setValue(testDecimal, for: .decimal)
        
        #expect(value.decimalValue == testDecimal)
        #expect(value.stringValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.hasValue == true)
    }
    
    @Test func testPickerValueStorage() throws {
        let field = CustomField(
            name: "Condition",
            fieldType: .picker,
            pickerOptions: ["Mint", "Good", "Fair"]
        )
        let value = CustomFieldValue(customField: field)
        
        value.setValue("Good", for: .picker)
        
        #expect(value.stringValue == "Good")
        #expect(value.isValidForField(field) == true)
        
        value.setValue("Invalid Option", for: .picker)
        #expect(value.isValidForField(field) == false)
    }
    
    @Test func testValueConversion() throws {
        let value = CustomFieldValue()
        
        // Test string to boolean conversion
        value.setValue("true", for: .boolean)
        #expect(value.boolValue == true)
        
        value.setValue("false", for: .boolean)
        #expect(value.boolValue == false)
        
        value.setValue("1", for: .boolean)
        #expect(value.boolValue == true)
        
        // Test string to decimal conversion
        value.setValue("123.45", for: .decimal)
        #expect(value.decimalValue == Decimal(123.45))
        
        // Test double to decimal conversion
        value.setValue(456.78, for: .decimal)
        #expect(value.decimalValue == Decimal(456.78))
    }
    
    // MARK: - Integration Tests
    
    @Test func testInventoryItemCustomFieldIntegration() throws {
        let item = InventoryItem()
        let field = CustomField(name: "Weight", fieldType: .decimal)
        
        testContext.insert(item)
        testContext.insert(field)
        
        // Test setting value
        item.setCustomFieldValue(Decimal(10.5), for: field)
        #expect(item.hasCustomFieldValue(for: field) == true)
        #expect(item.getCustomFieldDisplayValue(for: field) == "10.5")
        
        // Test getting value
        let value = item.getCustomFieldValue(for: field)
        #expect(value != nil)
        #expect(value?.decimalValue == Decimal(10.5))
        
        // Test removing value
        item.removeCustomFieldValue(for: field)
        #expect(item.hasCustomFieldValue(for: field) == false)
    }
    
    @Test func testCustomFieldValueClearingOnUpdate() throws {
        let value = CustomFieldValue()
        
        // Set initial value
        value.setValue("initial", for: .string)
        #expect(value.stringValue == "initial")
        
        // Set new value should clear others
        value.setValue(true, for: .boolean)
        #expect(value.boolValue == true)
        #expect(value.stringValue == nil) // Should be cleared
        
        // Set decimal should clear boolean
        value.setValue(Decimal(100), for: .decimal)
        #expect(value.decimalValue == Decimal(100))
        #expect(value.boolValue == nil) // Should be cleared
    }
}