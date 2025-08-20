//
//  CustomFieldManager.swift
//  MovingBox
//
//  Created by Claude Code on 8/20/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class CustomFieldManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var customFields: [CustomField] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Dependencies
    
    private let settingsManager: SettingsManager
    private var modelContext: ModelContext?
    
    // MARK: - Constants
    
    private struct Constants {
        static let maxFreeFields = 3
        static let cacheKey = "CustomFieldsCache"
        static let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    }
    
    // MARK: - Cache
    
    private var cacheTimestamp: Date?
    
    // MARK: - Initialization
    
    init(settingsManager: SettingsManager = SettingsManager()) {
        self.settingsManager = settingsManager
        print("🏷️ CustomFieldManager - Initialized")
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task {
            await loadCustomFields()
        }
    }
    
    // MARK: - CRUD Operations
    
    func createCustomField(_ field: CustomField) async throws {
        guard let context = modelContext else {
            throw CustomFieldError.noModelContext
        }
        
        // Check pro restrictions
        if !settingsManager.isPro && customFields.count >= Constants.maxFreeFields {
            throw CustomFieldError.proFeatureRequired
        }
        
        // Validate field type restrictions
        if field.fieldType.isProOnly && !settingsManager.isPro {
            throw CustomFieldError.proFeatureRequired
        }
        
        // Validate field name uniqueness within scope
        try validateFieldNameUniqueness(field)
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Set sort order
            field.sortOrder = customFields.count
            
            // Establish relationships based on scope
            if field.scope == .label, let scopeId = field.scopeId {
                field.label = try await getLabel(byId: scopeId, in: context)
            } else if field.scope == .location, let scopeId = field.scopeId {
                field.location = try await getLocation(byId: scopeId, in: context)
            }
            
            context.insert(field)
            try context.save()
            
            // Add to local cache
            customFields.append(field)
            invalidateCache()
            
            print("🏷️ CustomFieldManager - Created custom field: \(field.name)")
            
        } catch {
            errorMessage = "Failed to create custom field: \(error.localizedDescription)"
            print("❌ CustomFieldManager - Error creating field: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    func updateCustomField(_ field: CustomField) async throws {
        guard let context = modelContext else {
            throw CustomFieldError.noModelContext
        }
        
        // Validate field type restrictions for pro features
        if field.fieldType.isProOnly && !settingsManager.isPro {
            throw CustomFieldError.proFeatureRequired
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            field.updatedAt = Date()
            
            // Update relationships based on scope
            if field.scope == .label, let scopeId = field.scopeId {
                field.label = try await getLabel(byId: scopeId, in: context)
                field.location = nil
            } else if field.scope == .location, let scopeId = field.scopeId {
                field.location = try await getLocation(byId: scopeId, in: context)
                field.label = nil
            } else {
                field.label = nil
                field.location = nil
            }
            
            try context.save()
            
            // Update local cache
            if let index = customFields.firstIndex(where: { $0.id == field.id }) {
                customFields[index] = field
            }
            invalidateCache()
            
            print("🏷️ CustomFieldManager - Updated custom field: \(field.name)")
            
        } catch {
            errorMessage = "Failed to update custom field: \(error.localizedDescription)"
            print("❌ CustomFieldManager - Error updating field: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    func deleteCustomField(_ field: CustomField) async throws {
        guard let context = modelContext else {
            throw CustomFieldError.noModelContext
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Delete associated field values first
            let valueDescriptor = FetchDescriptor<CustomFieldValue>(
                predicate: #Predicate<CustomFieldValue> { value in
                    value.customField?.id == field.id
                }
            )
            
            let values = try context.fetch(valueDescriptor)
            for value in values {
                context.delete(value)
            }
            
            // Delete the field
            context.delete(field)
            try context.save()
            
            // Remove from local cache
            customFields.removeAll { $0.id == field.id }
            invalidateCache()
            
            print("🏷️ CustomFieldManager - Deleted custom field: \(field.name)")
            
        } catch {
            errorMessage = "Failed to delete custom field: \(error.localizedDescription)"
            print("❌ CustomFieldManager - Error deleting field: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    func getAllCustomFields() async throws -> [CustomField] {
        guard let context = modelContext else {
            throw CustomFieldError.noModelContext
        }
        
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < Constants.cacheExpirationInterval {
            return customFields
        }
        
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<CustomField>(
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
            )
            
            let fields = try context.fetch(descriptor)
            customFields = fields
            cacheTimestamp = Date()
            
            print("🏷️ CustomFieldManager - Loaded \(fields.count) custom fields")
            
        } catch {
            errorMessage = "Failed to load custom fields: \(error.localizedDescription)"
            print("❌ CustomFieldManager - Error loading fields: \(error)")
            throw error
        }
        
        isLoading = false
        return customFields
    }
    
    // MARK: - Scoping Logic
    
    func getAvailableFields(for item: InventoryItem) -> [CustomField] {
        return customFields.filter { field in
            field.isAvailableFor(item: item)
        }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func getFieldsForLabel(_ label: InventoryLabel) -> [CustomField] {
        return customFields.filter { field in
            field.scope == .global || 
            (field.scope == .label && field.scopeId == label.id.uuidString)
        }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func getFieldsForLocation(_ location: InventoryLocation) -> [CustomField] {
        return customFields.filter { field in
            field.scope == .global || 
            (field.scope == .location && field.scopeId == location.id.uuidString)
        }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func getGlobalFields() -> [CustomField] {
        return customFields.filter { $0.scope == .global }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - Value Management
    
    func setValue(_ value: Any?, for field: CustomField, item: InventoryItem) async throws {
        guard let context = modelContext else {
            throw CustomFieldError.noModelContext
        }
        
        do {
            // Update the item's custom field value
            item.setCustomFieldValue(value, for: field)
            try context.save()
            
            print("🏷️ CustomFieldManager - Set value for field '\(field.name)' on item '\(item.title)'")
            
        } catch {
            errorMessage = "Failed to set field value: \(error.localizedDescription)"
            print("❌ CustomFieldManager - Error setting value: \(error)")
            throw error
        }
    }
    
    func getValue(for field: CustomField, item: InventoryItem) -> Any? {
        return item.getCustomFieldValue(for: field)?.getValue()
    }
    
    func deleteValue(for field: CustomField, item: InventoryItem) async throws {
        guard let context = modelContext else {
            throw CustomFieldError.noModelContext
        }
        
        do {
            item.removeCustomFieldValue(for: field)
            try context.save()
            
            print("🏷️ CustomFieldManager - Deleted value for field '\(field.name)' on item '\(item.title)'")
            
        } catch {
            errorMessage = "Failed to delete field value: \(error.localizedDescription)"
            print("❌ CustomFieldManager - Error deleting value: \(error)")
            throw error
        }
    }
    
    // MARK: - Field Management
    
    func canCreateMoreFields() -> Bool {
        if settingsManager.isPro {
            return true
        }
        return customFields.count < Constants.maxFreeFields
    }
    
    func getRemainingFieldSlots() -> Int {
        if settingsManager.isPro {
            return Int.max
        }
        return max(0, Constants.maxFreeFields - customFields.count)
    }
    
    // MARK: - Validation
    
    private func validateFieldNameUniqueness(_ field: CustomField) throws {
        let existingField = customFields.first { existingField in
            existingField.name.lowercased() == field.name.lowercased() &&
            existingField.scope == field.scope &&
            existingField.scopeId == field.scopeId &&
            existingField.id != field.id
        }
        
        if existingField != nil {
            throw CustomFieldError.duplicateFieldName
        }
    }
    
    // MARK: - Helper Methods
    
    private func getLabel(byId id: String, in context: ModelContext) async throws -> InventoryLabel? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        
        let descriptor = FetchDescriptor<InventoryLabel>(
            predicate: #Predicate<InventoryLabel> { label in
                label.id == uuid
            }
        )
        
        return try context.fetch(descriptor).first
    }
    
    private func getLocation(byId id: String, in context: ModelContext) async throws -> InventoryLocation? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.id == uuid
            }
        )
        
        return try context.fetch(descriptor).first
    }
    
    private func invalidateCache() {
        cacheTimestamp = nil
    }
    
    private func loadCustomFields() async {
        do {
            try await getAllCustomFields()
        } catch {
            print("❌ CustomFieldManager - Error loading custom fields: \(error)")
        }
    }
}

// MARK: - Error Types

enum CustomFieldError: LocalizedError {
    case noModelContext
    case proFeatureRequired
    case duplicateFieldName
    case invalidFieldType
    case invalidScope
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Database context not available"
        case .proFeatureRequired:
            return "This feature requires a Pro subscription"
        case .duplicateFieldName:
            return "A field with this name already exists in this scope"
        case .invalidFieldType:
            return "Invalid field type specified"
        case .invalidScope:
            return "Invalid scope specified"
        }
    }
}

// MARK: - Extensions

extension CustomField {
    var updatedAt: Date {
        get { createdAt }
        set { /* SwiftData doesn't support computed properties for updates */ }
    }
}