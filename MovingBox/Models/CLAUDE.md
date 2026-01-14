# Models

SwiftData models for MovingBox inventory management.

## Core Models

| Model | Purpose | Key Relationships |
|-------|---------|-------------------|
| `InventoryItem` | User's possessions | → Location, → Labels |
| `InventoryLocation` | Rooms/areas | → Home, ← Items |
| `InventoryLabel` | Categories/tags | ← Items |
| `Home` | Property container | ← Locations, ← Policies |
| `InsurancePolicy` | Coverage details | → Home |

## Model Schema

```swift
@Model InventoryItem {
    name: String
    itemDescription: String
    estimatedValue: Decimal?
    purchasePrice: Decimal?
    location: InventoryLocation?
    labels: [InventoryLabel]
    // Photos via OptimizedImageManager, not stored in model
}

@Model InventoryLocation {
    name: String
    locationDescription: String?
    home: Home?
    items: [InventoryItem]  // inverse relationship
}

@Model InventoryLabel {
    name: String
    color: String?
    items: [InventoryItem]  // inverse relationship
}
```

## In-Memory Container for Testing

```swift
func createTestContainer() throws -> ModelContainer {
    let schema = Schema([
        InventoryItem.self,
        InventoryLocation.self,
        InventoryLabel.self,
        Home.self,
        InsurancePolicy.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
```

## Image Migration Pattern

Models with photos implement async migration from `@Attribute(.externalStorage)`:

```swift
// Called from model initializer
func migrateImageIfNeeded() async {
    guard let legacyData = self.photoData else { return }
    // Migrate to OptimizedImageManager
    try? await OptimizedImageManager.shared.saveImage(
        UIImage(data: legacyData)!,
        id: self.id.uuidString
    )
    self.photoData = nil  // Clear legacy storage
}
```

## Test Data
- `TestData.swift` - Sample items, locations, labels
- `DefaultDataManager` - Populates test data via "Use-Test-Data" launch argument
