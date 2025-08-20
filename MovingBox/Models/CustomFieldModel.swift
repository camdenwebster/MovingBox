//
//  CustomFieldModel.swift
//  MovingBox
//
//  Created by Claude Code on 8/20/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Supporting Enums

@objc enum CustomFieldType: Int, CaseIterable, Codable {
    case boolean = 0
    case string = 1
    case decimal = 2
    case picker = 3
    
    var displayName: String {
        switch self {
        case .boolean:
            return "Yes/No"
        case .string:
            return "Text"
        case .decimal:
            return "Number"
        case .picker:
            return "Multiple Choice"
        }
    }
    
    var systemImage: String {
        switch self {
        case .boolean:
            return "checkmark.square"
        case .string:
            return "textformat"
        case .decimal:
            return "number"
        case .picker:
            return "list.bullet"
        }
    }
    
    var isProOnly: Bool {
        switch self {
        case .boolean, .string:
            return false
        case .decimal, .picker:
            return true
        }
    }
}

@objc enum CustomFieldScope: Int, CaseIterable, Codable {
    case global = 0
    case label = 1
    case location = 2
    
    var displayName: String {
        switch self {
        case .global:
            return "All Items"
        case .label:
            return "Specific Label"
        case .location:
            return "Specific Location"
        }
    }
    
    var systemImage: String {
        switch self {
        case .global:
            return "globe"
        case .label:
            return "tag"
        case .location:
            return "location"
        }
    }
}

// MARK: - CustomField Model

@Model
final class CustomField {
    var id: UUID = UUID()
    var name: String = ""
    var fieldDescription: String = ""
    var fieldType: CustomFieldType = .string
    var scope: CustomFieldScope = .global
    var scopeId: String? = nil // UUID string of the label or location
    var isRequired: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var pickerOptions: [String] = []
    
    // Relationships
    var fieldValues: [CustomFieldValue]? = []
    var label: InventoryLabel? = nil
    var location: InventoryLocation? = nil
    
    init(
        name: String = "",
        fieldDescription: String = "",
        fieldType: CustomFieldType = .string,
        scope: CustomFieldScope = .global,
        scopeId: String? = nil,
        isRequired: Bool = false,
        sortOrder: Int = 0,
        pickerOptions: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.fieldDescription = fieldDescription
        self.fieldType = fieldType
        self.scope = scope
        self.scopeId = scopeId
        self.isRequired = isRequired
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.pickerOptions = pickerOptions
    }
    
    // MARK: - Convenience Methods
    
    var isPickerType: Bool {
        return fieldType == .picker
    }
    
    var hasPickerOptions: Bool {
        return isPickerType && !pickerOptions.isEmpty
    }
    
    var displayScope: String {
        switch scope {
        case .global:
            return scope.displayName
        case .label:
            return label?.name ?? "Unknown Label"
        case .location:
            return location?.name ?? "Unknown Location"
        }
    }
    
    func isAvailableFor(item: InventoryItem) -> Bool {
        switch scope {
        case .global:
            return true
        case .label:
            return item.label?.id.uuidString == scopeId
        case .location:
            return item.location?.id.uuidString == scopeId
        }
    }
    
    func addPickerOption(_ option: String) {
        guard fieldType == .picker else { return }
        guard !option.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !pickerOptions.contains(option) else { return }
        
        pickerOptions.append(option)
    }
    
    func removePickerOption(_ option: String) {
        guard fieldType == .picker else { return }
        pickerOptions.removeAll { $0 == option }
    }
    
    func validatePickerValue(_ value: String) -> Bool {
        guard fieldType == .picker else { return true }
        return pickerOptions.contains(value)
    }
}

// MARK: - Identifiable Conformance

extension CustomField: Identifiable {}

// MARK: - Hashable Conformance

extension CustomField: Hashable {
    static func == (lhs: CustomField, rhs: CustomField) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}