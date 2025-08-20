# Models Directory - MovingBox

This directory contains SwiftData model definitions for the MovingBox app's core data structures.

## Core Models

### Primary Entities
- **InventoryItem**: Individual items in user's inventory with photos and AI analysis
- **InventoryLocation**: Rooms and locations where items are stored  
- **InventoryLabel**: Tags and categories for organizing items
- **Home**: User's property containing locations and insurance information
- **InsurancePolicy**: Insurance coverage details linked to homes

### Supporting Protocols
- **PhotoManageable**: Protocol for models that can store and manage photos

## SwiftData Best Practices

### Model Definition
- Use `@Model` macro for all persistent model classes
- Implement proper relationships with appropriate delete rules
- Use `@Attribute` for special storage requirements
- Follow Swift naming conventions (PascalCase for types)

### Relationships
- Define bidirectional relationships appropriately
- Use cascade delete rules where data integrity requires it
- Consider performance implications of relationship loading
- Implement proper inverse relationships

### Data Migration
- Implement `migrateImageIfNeeded()` for models requiring image migration
- Call migration methods from model initializers
- Handle async migration patterns properly
- Test migration scenarios thoroughly

### Image Storage
- **Legacy**: `@Attribute(.externalStorage)` for SwiftData external storage
- **Current**: Use `OptimizedImageManager` for new implementations
- Migrate from external storage to optimized storage for better performance
- Handle image URLs and data consistently

## Model-Specific Guidelines

### InventoryItem
- Primary entity representing user's possessions
- Stores multiple photos via `OptimizedImageManager`
- Contains AI analysis results from OpenAI Vision API
- Links to location and labels for organization
- Includes valuation and insurance information

**Key Properties:**
- `name`: Item display name
- `itemDescription`: Detailed description
- `estimatedValue`: User-estimated or AI-suggested value
- `purchasePrice`: Original purchase price if known
- `photos`: Array of photo identifiers
- `aiAnalysis`: Structured AI analysis results
- `location`: Reference to InventoryLocation
- `labels`: Collection of InventoryLabel references

### InventoryLocation
- Represents rooms, closets, storage areas within a home
- Contains multiple inventory items
- May have a representative photo
- Organized hierarchically (optional parent locations)

**Key Properties:**
- `name`: Location display name
- `locationDescription`: Additional details
- `items`: Collection of InventoryItem references
- `photo`: Optional representative photo
- `home`: Reference to Home

### InventoryLabel
- Flexible tagging system for categorizing items
- Supports hierarchical organization
- Used for filtering and search

**Key Properties:**
- `name`: Label display name
- `color`: Visual identifier color
- `items`: Collection of tagged InventoryItem references

### Home
- Top-level container for user's property
- Contains locations and insurance policies
- Supports multiple homes per user

**Key Properties:**
- `name`: Property name/address
- `homeDescription`: Additional details
- `locations`: Collection of InventoryLocation references
- `insurancePolicies`: Collection of InsurancePolicy references
- `photo`: Optional representative photo

### InsurancePolicy
- Insurance coverage information
- Links to specific home
- Tracks coverage limits and details

**Key Properties:**
- `policyNumber`: Insurance policy identifier
- `provider`: Insurance company name
- `coverageAmount`: Total coverage limit
- `deductible`: Policy deductible amount
- `home`: Reference to covered Home

## Data Validation

### Input Validation
- Validate required fields before saving
- Implement reasonable string length limits
- Validate numeric values (prices, coverage amounts)
- Sanitize user input appropriately

### Business Logic Validation
- Ensure relationships are valid before saving
- Validate that items belong to appropriate locations
- Check insurance coverage limits are reasonable
- Implement cross-field validation where needed

### Error Handling
- Use Result types for validation outcomes
- Provide meaningful error messages
- Handle database constraint violations gracefully
- Implement recovery mechanisms where possible

## Performance Considerations

### Query Optimization
- Use appropriate fetch descriptors and predicates
- Limit query results when displaying large lists
- Implement pagination for large datasets
- Use relationship prefetching judiciously

### Memory Management
- Avoid loading unnecessary relationships
- Use fault objects appropriately
- Implement proper cleanup for large operations
- Monitor memory usage during bulk operations

### Background Processing
- Use background contexts for heavy operations
- Implement proper context merging strategies
- Handle concurrent access appropriately
- Consider queue management for bulk updates

## Testing Strategies

### Unit Testing
- Use in-memory containers for test isolation
- Create proper test data setup/teardown
- Test model relationships and constraints
- Verify migration logic thoroughly

### Test Data
- Use `TestData.swift` for consistent test scenarios
- Create realistic test datasets
- Test edge cases and boundary conditions
- Implement data cleanup between tests

### Mock Data
- Provide representative mock data for UI testing
- Handle empty states and error conditions
- Create varied datasets for visual testing
- Consider performance impact of large mock datasets

## Migration Patterns

### Schema Evolution
- Plan schema changes carefully
- Implement progressive migration strategies
- Test migration paths thoroughly
- Provide fallback mechanisms where possible

### Image Migration
- Migrate from `@Attribute(.externalStorage)` to `OptimizedImageManager`
- Handle missing or corrupted images gracefully
- Implement async migration with proper error handling
- Test with various data states and edge cases

### Data Integrity
- Validate data consistency after migrations
- Implement repair mechanisms for corrupted data
- Log migration progress and errors appropriately
- Provide user feedback for long-running migrations

## Integration Points

### AI Service Integration
- Store AI analysis results consistently
- Handle AI service errors and retries
- Implement structured response parsing
- Consider AI result versioning for future improvements

### Cloud Sync Integration
- Design models for CloudKit compatibility
- Handle sync conflicts appropriately
- Implement proper merge strategies
- Consider offline-first design patterns

### Export/Import
- Support CSV export for user data portability
- Implement proper data serialization
- Handle large datasets efficiently
- Maintain data integrity during export/import

## Security Considerations

### Data Protection
- Avoid storing sensitive information in plaintext
- Implement proper access controls
- Consider data encryption for sensitive fields
- Handle user data deletion appropriately

### Privacy Compliance
- Support data export for user requests
- Implement proper data deletion mechanisms
- Consider data retention policies
- Handle user consent appropriately

### Audit Trail
- Log significant data changes where appropriate
- Implement proper versioning for critical data
- Consider tamper detection for insurance data
- Maintain data lineage for important operations