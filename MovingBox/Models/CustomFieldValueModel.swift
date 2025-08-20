//
//  CustomFieldValueModel.swift
//  MovingBox
//
//  Created by Claude Code on 8/20/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - CustomFieldValue Model

@Model
final class CustomFieldValue {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Type-specific value storage
    var stringValue: String? = nil
    var boolValue: Bool? = nil
    var decimalValue: Decimal? = nil
    
    // Relationships
    var customField: CustomField?
    var inventoryItem: InventoryItem?
    
    init(
        customField: CustomField? = nil,
        inventoryItem: InventoryItem? = nil,
        stringValue: String? = nil,
        boolValue: Bool? = nil,
        decimalValue: Decimal? = nil
    ) {
        self.id = UUID()
        self.customField = customField
        self.inventoryItem = inventoryItem
        self.stringValue = stringValue
        self.boolValue = boolValue
        self.decimalValue = decimalValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Value Management
    
    func setValue(_ value: Any?, for fieldType: CustomFieldType) {
        let now = Date()
        updatedAt = now
        
        // Clear all values first
        stringValue = nil
        boolValue = nil
        decimalValue = nil
        
        guard let value = value else { return }
        
        switch fieldType {
        case .string, .picker:
            if let stringVal = value as? String {
                stringValue = stringVal.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                stringValue = String(describing: value)
            }
            
        case .boolean:
            if let boolVal = value as? Bool {
                boolValue = boolVal
            } else if let stringVal = value as? String {
                boolValue = stringVal.lowercased() == "true" || stringVal == "1"
            }
            
        case .decimal:
            if let decimalVal = value as? Decimal {
                decimalValue = decimalVal
            } else if let doubleVal = value as? Double {
                decimalValue = Decimal(doubleVal)
            } else if let intVal = value as? Int {
                decimalValue = Decimal(intVal)
            } else if let stringVal = value as? String,
                      let doubleVal = Double(stringVal) {
                decimalValue = Decimal(doubleVal)
            }
        }
    }
    
    func getValue() -> Any? {
        if let stringValue = stringValue {
            return stringValue
        }
        if let boolValue = boolValue {
            return boolValue
        }
        if let decimalValue = decimalValue {
            return decimalValue
        }
        return nil
    }
    
    func getTypedValue<T>() -> T? {
        return getValue() as? T
    }
    
    func getDisplayValue() -> String {
        guard let value = getValue() else { return "" }
        
        switch value {
        case let boolVal as Bool:
            return boolVal ? "Yes" : "No"
        case let decimalVal as Decimal:
            return decimalVal.formatted(.number.precision(.fractionLength(0...2)))
        case let stringVal as String:
            return stringVal
        default:
            return String(describing: value)
        }
    }
    
    var hasValue: Bool {
        return stringValue != nil || boolValue != nil || decimalValue != nil
    }
    
    var isEmpty: Bool {
        if let string = stringValue {
            return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !hasValue
    }
    
    // MARK: - Validation
    
    func isValidForField(_ field: CustomField) -> Bool {
        guard let fieldType = customField?.fieldType ?? field.fieldType else { return false }
        
        switch fieldType {
        case .string:
            return stringValue != nil
        case .boolean:
            return boolValue != nil
        case .decimal:
            return decimalValue != nil
        case .picker:
            guard let stringVal = stringValue,
                  !stringVal.isEmpty else { return false }
            return field.validatePickerValue(stringVal)
        }
    }
    
    // MARK: - Convenience Initializers
    
    convenience init(field: CustomField, item: InventoryItem, stringValue: String) {
        self.init(customField: field, inventoryItem: item)
        setValue(stringValue, for: field.fieldType)
    }
    
    convenience init(field: CustomField, item: InventoryItem, boolValue: Bool) {
        self.init(customField: field, inventoryItem: item)
        setValue(boolValue, for: field.fieldType)
    }
    
    convenience init(field: CustomField, item: InventoryItem, decimalValue: Decimal) {
        self.init(customField: field, inventoryItem: item)
        setValue(decimalValue, for: field.fieldType)
    }
}

// MARK: - Identifiable Conformance

extension CustomFieldValue: Identifiable {}

// MARK: - Hashable Conformance

extension CustomFieldValue: Hashable {
    static func == (lhs: CustomFieldValue, rhs: CustomFieldValue) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}