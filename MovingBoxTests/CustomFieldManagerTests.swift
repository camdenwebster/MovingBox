//
//  CustomFieldManagerTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 8/20/25.
//

import Testing
import SwiftData
@testable import MovingBox

@MainActor
struct CustomFieldManagerTests {
    
    let testContainer: ModelContainer
    let testContext: ModelContext
    let settingsManager: SettingsManager
    let customFieldManager: CustomFieldManager
    
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
        
        // Create mock settings manager
        settingsManager = SettingsManager()
        customFieldManager = CustomFieldManager(settingsManager: settingsManager)
        customFieldManager.setModelContext(testContext)
    }
    
    // MARK: - Field Creation Tests
    
    @Test func testCreateCustomField() async throws {
        let field = CustomField(
            name: "Test Field",
            fieldDescription: "A test field",
            fieldType: .string,
            scope: .global
        )
        
        try await customFieldManager.createCustomField(field)
        
        let fields = try await customFieldManager.getAllCustomFields()
        #expect(fields.count == 1)
        #expect(fields.first?.name == "Test Field")
    }
    
    @Test func testCreateFieldWithProRestrictions() async throws {
        // Set as free user
        settingsManager.isPro = false
        
        let proField = CustomField(
            name: "Pro Field",
            fieldType: .picker,
            pickerOptions: ["Option 1", "Option 2"]
        )
        
        do {
            try await customFieldManager.createCustomField(proField)
            Issue.record("Expected pro feature error but creation succeeded")
        } catch CustomFieldError.proFeatureRequired {
            // Expected error for pro-only field type
        }
    }
    
    @Test func testFreeUserFieldLimit() async throws {
        // Set as free user
        settingsManager.isPro = false
        
        // Create maximum free fields
        for i in 1...3 {
            let field = CustomField(name: "Field \(i)", fieldType: .string)
            try await customFieldManager.createCustomField(field)
        }
        
        // Try to create one more (should fail)
        let extraField = CustomField(name: "Extra Field", fieldType: .string)
        
        do {
            try await customFieldManager.createCustomField(extraField)
            Issue.record("Expected field limit error but creation succeeded")
        } catch CustomFieldError.proFeatureRequired {
            // Expected error for exceeding field limit
        }
        
        // Verify field count
        #expect(customFieldManager.canCreateMoreFields() == false)
        #expect(customFieldManager.getRemainingFieldSlots() == 0)
    }
    
    @Test func testProUserUnlimitedFields() async throws {
        // Set as pro user
        settingsManager.isPro = true
        
        // Create more than free limit
        for i in 1...5 {
            let field = CustomField(name: "Field \(i)", fieldType: .string)
            try await customFieldManager.createCustomField(field)
        }
        
        let fields = try await customFieldManager.getAllCustomFields()
        #expect(fields.count == 5)
        #expect(customFieldManager.canCreateMoreFields() == true)
    }
    
    // MARK: - Field Management Tests
    
    @Test func testUpdateCustomField() async throws {
        let field = CustomField(name: "Original Name", fieldType: .string)
        try await customFieldManager.createCustomField(field)
        
        // Update the field
        field.name = "Updated Name"
        field.fieldDescription = "Updated description"
        
        try await customFieldManager.updateCustomField(field)
        
        let fields = try await customFieldManager.getAllCustomFields()
        let updatedField = fields.first { $0.id == field.id }
        
        #expect(updatedField?.name == "Updated Name")
        #expect(updatedField?.fieldDescription == "Updated description")
    }
    
    @Test func testDeleteCustomField() async throws {
        let field = CustomField(name: "To Delete", fieldType: .string)
        try await customFieldManager.createCustomField(field)
        
        // Verify it exists
        var fields = try await customFieldManager.getAllCustomFields()
        #expect(fields.count == 1)
        
        // Delete it
        try await customFieldManager.deleteCustomField(field)
        
        // Verify it's gone
        fields = try await customFieldManager.getAllCustomFields()
        #expect(fields.count == 0)
    }
    
    // MARK: - Scoping Tests
    
    @Test func testGlobalFieldScoping() async throws {
        let globalField = CustomField(name: "Global Field", scope: .global)
        try await customFieldManager.createCustomField(globalField)
        
        // Create test item
        let item = InventoryItem()
        testContext.insert(item)
        
        let availableFields = customFieldManager.getAvailableFields(for: item)
        #expect(availableFields.count == 1)
        #expect(availableFields.first?.name == "Global Field")
    }
    
    @Test func testLabelSpecificScoping() async throws {
        // Create test label and item
        let electronics = InventoryLabel(name: "Electronics")
        let furniture = InventoryLabel(name: "Furniture")
        
        let electronicsItem = InventoryItem()
        electronicsItem.label = electronics
        
        let furnitureItem = InventoryItem()
        furnitureItem.label = furniture
        
        testContext.insert(electronics)
        testContext.insert(furniture)
        testContext.insert(electronicsItem)
        testContext.insert(furnitureItem)
        
        // Create label-specific field
        let electronicsField = CustomField(
            name: "Warranty",
            scope: .label,
            scopeId: electronics.id.uuidString
        )
        
        try await customFieldManager.createCustomField(electronicsField)
        
        // Test availability
        let electronicsFields = customFieldManager.getAvailableFields(for: electronicsItem)
        let furnitureFields = customFieldManager.getAvailableFields(for: furnitureItem)
        
        #expect(electronicsFields.count == 1)
        #expect(furnitureFields.count == 0)
    }
    
    @Test func testLocationSpecificScoping() async throws {
        // Create test location and item
        let kitchen = InventoryLocation(name: "Kitchen")
        let bedroom = InventoryLocation(name: "Bedroom")
        
        let kitchenItem = InventoryItem()
        kitchenItem.location = kitchen
        
        let bedroomItem = InventoryItem()
        bedroomItem.location = bedroom
        
        testContext.insert(kitchen)
        testContext.insert(bedroom)
        testContext.insert(kitchenItem)
        testContext.insert(bedroomItem)
        
        // Create location-specific field
        let kitchenField = CustomField(
            name: "Recipe Notes",
            scope: .location,
            scopeId: kitchen.id.uuidString
        )
        
        try await customFieldManager.createCustomField(kitchenField)
        
        // Test availability
        let kitchenFields = customFieldManager.getAvailableFields(for: kitchenItem)
        let bedroomFields = customFieldManager.getAvailableFields(for: bedroomItem)
        
        #expect(kitchenFields.count == 1)
        #expect(bedroomFields.count == 0)
    }
    
    // MARK: - Value Management Tests
    
    @Test func testSetAndGetFieldValue() async throws {
        let field = CustomField(name: "Notes", fieldType: .string)
        let item = InventoryItem(title: "Test Item")
        
        testContext.insert(field)
        testContext.insert(item)
        try await customFieldManager.createCustomField(field)
        
        // Set value
        try await customFieldManager.setValue("Test notes", for: field, item: item)
        
        // Get value
        let value = customFieldManager.getValue(for: field, item: item)
        #expect(value as? String == "Test notes")
    }
    
    @Test func testDeleteFieldValue() async throws {
        let field = CustomField(name: "Rating", fieldType: .decimal)
        let item = InventoryItem(title: "Test Item")
        
        testContext.insert(field)
        testContext.insert(item)
        try await customFieldManager.createCustomField(field)
        
        // Set value
        try await customFieldManager.setValue(Decimal(5), for: field, item: item)
        #expect(item.hasCustomFieldValue(for: field) == true)
        
        // Delete value
        try await customFieldManager.deleteValue(for: field, item: item)
        #expect(item.hasCustomFieldValue(for: field) == false)
    }
    
    // MARK: - Helper Method Tests
    
    @Test func testGetFieldsByLabel() async throws {
        let electronics = InventoryLabel(name: "Electronics")
        testContext.insert(electronics)
        
        let globalField = CustomField(name: "Global", scope: .global)
        let labelField = CustomField(
            name: "Label Specific",
            scope: .label,
            scopeId: electronics.id.uuidString
        )
        let otherLabelField = CustomField(
            name: "Other Label",
            scope: .label,
            scopeId: UUID().uuidString
        )
        
        try await customFieldManager.createCustomField(globalField)
        try await customFieldManager.createCustomField(labelField)
        try await customFieldManager.createCustomField(otherLabelField)
        
        let fieldsForElectronics = customFieldManager.getFieldsForLabel(electronics)
        
        #expect(fieldsForElectronics.count == 2)
        #expect(fieldsForElectronics.contains { $0.name == "Global" })
        #expect(fieldsForElectronics.contains { $0.name == "Label Specific" })
        #expect(!fieldsForElectronics.contains { $0.name == "Other Label" })
    }
    
    @Test func testGetFieldsByLocation() async throws {
        let kitchen = InventoryLocation(name: "Kitchen")
        testContext.insert(kitchen)
        
        let globalField = CustomField(name: "Global", scope: .global)
        let locationField = CustomField(
            name: "Location Specific",
            scope: .location,
            scopeId: kitchen.id.uuidString
        )
        
        try await customFieldManager.createCustomField(globalField)
        try await customFieldManager.createCustomField(locationField)
        
        let fieldsForKitchen = customFieldManager.getFieldsForLocation(kitchen)
        
        #expect(fieldsForKitchen.count == 2)
        #expect(fieldsForKitchen.contains { $0.name == "Global" })
        #expect(fieldsForKitchen.contains { $0.name == "Location Specific" })
    }
    
    @Test func testGetGlobalFields() async throws {
        let globalField1 = CustomField(name: "Global 1", scope: .global)
        let globalField2 = CustomField(name: "Global 2", scope: .global)
        let labelField = CustomField(name: "Label Field", scope: .label, scopeId: UUID().uuidString)
        
        try await customFieldManager.createCustomField(globalField1)
        try await customFieldManager.createCustomField(globalField2)
        try await customFieldManager.createCustomField(labelField)
        
        let globalFields = customFieldManager.getGlobalFields()
        
        #expect(globalFields.count == 2)
        #expect(globalFields.allSatisfy { $0.scope == .global })
    }
}