# Product Requirements Document: Custom Inventory Fields

## Overview

This PRD outlines the implementation of custom inventory fields that allow users to extend the default inventory item schema with user-defined fields. This feature will enable users to customize their inventory management to suit specific needs while maintaining the core functionality of MovingBox.

## Problem Statement

Currently, MovingBox provides a fixed set of inventory fields (title, description, serial, model, make, quantity, price, etc.). Users have expressed the need to add custom fields for:
- Category-specific information (e.g., warranty expiration for electronics, size for clothing)
- Location-specific metadata (e.g., room temperature for wine storage)
- Personal organization systems (e.g., custom numbering, tags, ratings)

## Goals

### Primary Goals
- Enable users to create custom fields for inventory items
- Support multiple field types: boolean, string, decimal, picker (predefined options)
- Allow optional scoping to specific labels or locations
- Integrate seamlessly with existing inventory management workflows

### Secondary Goals
- Maintain backward compatibility with existing inventory data
- Ensure custom fields are included in export/import functionality
- Provide pro subscription gating for advanced custom field features

## User Stories

### Core User Stories

**As a user, I want to create custom fields so that I can track information specific to my needs.**
- Acceptance Criteria:
  - User can access custom fields settings from main settings screen
  - User can create new custom fields with name and type
  - Created fields appear in inventory item creation/editing forms

**As a user, I want to choose different field types so that I can capture the right kind of data.**
- Acceptance Criteria:
  - Support for Boolean (yes/no, true/false)
  - Support for String (text input, single line)
  - Support for Decimal (numeric input with decimal places)
  - Support for Picker (dropdown with predefined options)

**As a user, I want to scope custom fields to specific labels or locations so that relevant fields appear in appropriate contexts.**
- Acceptance Criteria:
  - Option to make field global (all items) or scoped to specific label/location
  - Fields only appear in forms when conditions are met
  - Clear indication of field scope in settings

### Advanced User Stories

**As a user, I want to manage my custom fields so that I can maintain my organization system.**
- Acceptance Criteria:
  - Edit existing custom fields (name, options, scope)
  - Delete unused custom fields with confirmation
  - Reorder custom fields for better organization

**As a user, I want custom field data included in exports so that I don't lose information when backing up.**
- Acceptance Criteria:
  - Custom fields included in CSV export
  - Custom field definitions preserved in import/export process
  - Migration support for custom field changes

## Technical Requirements

### Data Model

#### CustomField Model
```swift
@Model
final class CustomField {
    var id: UUID
    var name: String
    var fieldType: CustomFieldType
    var options: [String] // For picker type
    var isRequired: Bool
    var scope: CustomFieldScope
    var targetLabelId: UUID? // For label-scoped fields
    var targetLocationId: UUID? // For location-scoped fields
    var sortOrder: Int
    var isActive: Bool
    var createdDate: Date
}
```

#### CustomFieldType Enum
```swift
enum CustomFieldType: String, CaseIterable, Codable {
    case boolean
    case string
    case decimal
    case picker
}
```

#### CustomFieldScope Enum
```swift
enum CustomFieldScope: String, CaseIterable, Codable {
    case global
    case label
    case location
}
```

#### CustomFieldValue Model
```swift
@Model
final class CustomFieldValue {
    var id: UUID
    var customField: CustomField
    var inventoryItem: InventoryItem
    var stringValue: String?
    var decimalValue: Decimal?
    var booleanValue: Bool?
}
```

### UI Components

#### CustomFieldsSettingsView
- Main settings screen for managing custom fields
- List of existing custom fields with edit/delete actions
- Add button for creating new custom fields
- Proper integration with existing settings navigation

#### CustomFieldEditorView
- Modal/sheet for creating/editing custom fields
- Form with field name, type selection, scope options
- Picker options management for picker-type fields
- Validation for required fields

#### Dynamic Form Integration
- Modify `InventoryDetailView` and `AddInventoryItemView` to include custom fields
- Dynamic form generation based on item's label/location and global fields
- Proper value binding and validation for different field types

### Business Logic

#### CustomFieldManager
- Service class for managing custom field operations
- CRUD operations for custom fields and values
- Logic for determining applicable fields for given item context
- Validation and data type conversion utilities

#### Integration Points
- Export/Import functionality must include custom fields
- Search and filtering should consider custom field values
- Pro subscription gating for advanced features (e.g., unlimited fields, complex scoping)

## Technical Considerations

### Database Migration
- Schema updates to support new models
- Migration strategy for existing installations
- CloudKit sync considerations for new data types

### Performance
- Efficient queries for custom field lookup
- Lazy loading of custom field values
- Optimal storage strategy for different value types

### Data Validation
- Type-safe value storage and retrieval
- Input validation for different field types
- Error handling for invalid custom field configurations

### Export/Import Compatibility
- Extend DataManager to include custom field definitions
- CSV format considerations for dynamic columns
- ZIP export structure for custom field metadata

## Success Metrics

### User Adoption
- Percentage of users who create at least one custom field within 30 days
- Average number of custom fields created per user
- Retention rate for users who use custom fields

### Feature Usage
- Most popular custom field types
- Usage patterns for field scoping (global vs. label/location)
- Export/import usage with custom fields

### Technical Performance
- Custom field query performance metrics
- Memory usage impact of dynamic forms
- CloudKit sync performance with additional data

## Risks and Mitigations

### Risk: Performance Impact
- Mitigation: Implement efficient querying and caching strategies
- Mitigation: Profile performance with realistic data volumes

### Risk: Complex UI for Dynamic Forms
- Mitigation: Prototype key user flows early
- Mitigation: Implement progressive disclosure for advanced features

### Risk: Data Migration Complexity
- Mitigation: Comprehensive testing with various data states
- Mitigation: Rollback strategies for failed migrations

### Risk: CloudKit Sync Complexity
- Mitigation: Thorough testing of sync scenarios
- Mitigation: Conflict resolution strategies for custom field changes

## Future Considerations

### Phase 2 Features
- Multi-line text fields
- Date/time fields  
- Photo attachment fields (beyond main photos)
- Calculated fields based on other field values

### Advanced Features
- Custom field templates for common use cases
- Bulk operations on custom field values
- Advanced reporting and analytics on custom fields
- API access to custom fields for third-party integrations

## Implementation Timeline

### Phase 1: Core Infrastructure (2-3 weeks)
- Data models and database migration
- Basic CustomFieldManager service
- Core CRUD operations with tests

### Phase 2: UI Implementation (2-3 weeks)
- CustomFieldsSettingsView
- CustomFieldEditorView  
- Dynamic form integration

### Phase 3: Integration and Polish (1-2 weeks)
- Export/import support
- Pro subscription gating
- Performance optimization
- Comprehensive testing

### Phase 4: Release Preparation (1 week)
- Beta testing and feedback integration
- Documentation updates
- Release notes and marketing materials