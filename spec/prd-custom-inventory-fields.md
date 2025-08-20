# Product Requirements Document: Custom Inventory Fields

## Introduction/Overview

This feature enables users to define custom inventory fields beyond the default set provided by MovingBox. Users can create personalized fields to capture specific data relevant to their inventory needs, with optional scoping to labels or locations for better organization and specificity.

**Problem Solved**: Different users have varying inventory tracking needs that go beyond standard fields (title, description, price, etc.). For example, collectors might need fields for "condition rating" or "year manufactured," while businesses might need "warranty expiration" or "supplier information."

**Goal**: Provide flexible, user-defined fields that extend inventory items without compromising the existing simple and intuitive experience.

## Goals

1. Allow users to create custom fields with different data types (boolean, string, decimal, picker)
2. Enable optional scoping of fields to specific labels or locations
3. Provide a settings interface for managing custom fields
4. Maintain backwards compatibility with existing inventory data
5. Support export/import functionality for custom field data
6. Gate advanced custom field features behind pro subscription

## User Stories

1. **As a collector documenting vintage items**, I want to create a "Condition" picker field with values (Mint, Good, Fair, Poor) so that I can consistently rate my items.

2. **As a business owner tracking equipment**, I want to create a "Warranty Expires" date field scoped to my "Electronics" label so that I can track when warranties expire.

3. **As a homeowner with multiple properties**, I want to create location-specific fields like "Room" for my "Main House" location so that I can be more specific about item placement.

4. **As a user managing household items**, I want to create a "Is Insured" boolean field so that I can track which items are covered by my insurance policy.

5. **As a user organizing my inventory**, I want to see custom field values in my item detail views so that all my information is displayed together.

6. **As a user exporting my data**, I want custom field values included in my CSV exports so that I don't lose any data when moving between systems.

## Functional Requirements

### Custom Field Management
1. Users must be able to create new custom fields with a name, description, and data type
2. Supported data types: Boolean, String, Decimal, Picker (with predefined options)
3. Users must be able to edit existing custom field definitions
4. Users must be able to delete custom fields (with confirmation)
5. Custom field names must be unique within their scope

### Scoping System
6. Fields can be set as "Global" (available for all inventory items)
7. Fields can be scoped to specific labels (only available for items with that label)
8. Fields can be scoped to specific locations (only available for items in that location)
9. Users must be able to change the scope of existing fields

### Data Input and Display
10. Custom fields must appear in the Add/Edit inventory item forms based on scoping rules
11. Boolean fields must display as toggles/switches
12. String fields must display as text input fields
13. Decimal fields must display as number input fields with proper formatting
14. Picker fields must display as selection menus with predefined options
15. Custom field values must display in the inventory item detail view

### Settings Interface
16. A "Custom Fields" settings view must allow users to manage all custom fields
17. The interface must clearly show field name, type, scope, and usage count
18. Users must be able to search/filter their custom fields
19. The interface must provide clear visual hierarchy for different scopes

### Data Storage and Persistence
20. Custom field definitions must be stored persistently
21. Custom field values must be stored with proper relationships to inventory items
22. Data must support CloudKit synchronization
23. Proper data migration must be implemented for schema changes

### Export/Import Integration
24. Custom field values must be included in CSV exports
25. Custom field definitions must be exportable for backup purposes
26. Import functionality must handle custom field data appropriately

### Pro Feature Integration
27. Free tier users are limited to 3 custom fields maximum
28. Pro users have unlimited custom fields
29. Advanced field types (picker) are pro-only features
30. Proper paywall integration for field creation limits

## Non-Goals (Out of Scope)

1. Conditional field display based on other field values
2. Complex validation rules for custom fields
3. Field calculations or formulas
4. Rich text or markdown support in string fields
5. Image or file attachment custom fields
6. Multi-select picker fields
7. Date/time picker fields (planned for future version)
8. Field ordering or custom layouts in forms

## Design Considerations

- Follow the existing app design patterns and visual hierarchy
- Maintain consistency with existing settings views
- Use clear icons and labels to distinguish field types
- Provide helpful placeholder text and examples
- Ensure custom fields integrate seamlessly into existing item forms
- Consider performance impact of dynamic form generation

## Technical Considerations

### Data Models
- Create `CustomField` SwiftData model with name, type, scope, and configuration
- Create `CustomFieldValue` SwiftData model with type-safe value storage
- Establish proper relationships between fields, values, and inventory items
- Implement value transformers for complex data types

### Service Layer
- Create `CustomFieldManager` service following existing manager patterns
- Handle field validation and value type conversion
- Manage scoping logic and field availability
- Implement caching for performance optimization

### Form Integration
- Dynamic form generation based on available custom fields
- Type-specific input components that integrate with existing form styling
- Proper validation and error handling for custom field inputs

### Performance Considerations
- Lazy loading of custom field values
- Efficient querying with proper SwiftData predicates
- Caching of field definitions to minimize database queries
- Proper indexing for frequently queried relationships

### CloudKit Integration
- Ensure custom field models are CloudKit-compatible
- Handle sync conflicts for custom field data
- Proper record naming and relationship handling

## Success Metrics

1. **User Adoption**: 40% of pro users create at least one custom field within 30 days
2. **Data Quality**: Items with custom fields have 15% more complete data profiles
3. **User Retention**: Users with custom fields show 20% higher retention after 90 days
4. **Performance**: Custom field forms load within 500ms
5. **Error Rate**: Less than 2% of custom field operations result in errors

## Open Questions

1. Should custom fields support default values for new items?
2. How should we handle custom field data when users downgrade from pro?
3. Should we provide field templates or presets for common use cases?
4. How should we handle bulk editing of custom field values?
5. Should custom fields be included in search functionality?
6. What's the optimal caching strategy for custom field definitions?
7. Should we support field dependencies (showing field B only when field A has specific value)?