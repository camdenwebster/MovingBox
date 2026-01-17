# MovingBox Modular Refactoring Plan

## Executive Summary

This document outlines a phased approach to modularize MovingBox into local Swift packages. The goal is to:

1. **Speed up development** with faster incremental builds
2. **Extract business logic** from iOS-specific implementation
3. **Abstract persistence** for future SwiftData → SQLite migration
4. **Enable code sharing** across future apps via remote packages

---

## Target Package Architecture

```
MovingBox/
├── Packages/
│   ├── Core/                     # Foundation layer (no dependencies)
│   │   └── MovingBoxCore/
│   │
│   ├── Domain/                   # Business logic layer
│   │   ├── InventoryDomain/      # Inventory business rules
│   │   └── ExportDomain/         # Data export logic
│   │
│   ├── Data/                     # Persistence abstraction layer
│   │   ├── DataAbstractions/     # Protocols & repository interfaces
│   │   ├── SwiftDataProvider/    # SwiftData implementation
│   │   └── ImageStorage/         # Image management
│   │
│   ├── Services/                 # External service integrations
│   │   ├── AIService/            # OpenAI/Vision API
│   │   ├── AnalyticsService/     # TelemetryDeck
│   │   ├── PurchaseService/      # RevenueCat
│   │   └── SyncService/          # CloudKit abstraction
│   │
│   ├── UI/                       # Shared UI components
│   │   └── DesignSystem/         # Reusable components, modifiers, constants
│   │
│   └── Features/                 # Feature modules (MVVM)
│       ├── DashboardFeature/
│       ├── InventoryFeature/
│       ├── LocationsFeature/
│       ├── SettingsFeature/
│       └── OnboardingFeature/
│
└── MovingBox/                    # Main app target
    ├── App/                      # App entry, DI container, navigation shell
    └── Resources/                # Assets, Info.plist
```

---

## Package Dependency Graph

```
                    ┌─────────────────────┐
                    │   MovingBox (App)   │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │   Features   │   │   Services   │   │     UI       │
    │ (Dashboard,  │   │ (AI, Purchase│   │ (DesignSystem│
    │  Inventory)  │   │   Analytics) │   │  Components) │
    └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
           │                  │                   │
           ▼                  ▼                   │
    ┌──────────────┐   ┌──────────────┐          │
    │    Domain    │   │     Data     │          │
    │  (Business   │◄──│ (Persistence │          │
    │    Rules)    │   │ Abstraction) │          │
    └──────┬───────┘   └──────┬───────┘          │
           │                  │                   │
           └────────┬─────────┴───────────────────┘
                    ▼
             ┌──────────────┐
             │     Core     │
             │ (Utilities,  │
             │  Extensions) │
             └──────────────┘
```

### Dependency Rules

1. **Core** → No dependencies (pure Swift)
2. **Domain** → Core only
3. **Data** → Core, Domain (for repository protocols)
4. **Services** → Core, Domain
5. **UI** → Core only
6. **Features** → All of the above
7. **App** → All packages (composition root)

---

## Package Specifications

### 1. MovingBoxCore (Foundation Layer)

**Purpose:** Pure Swift utilities, extensions, and common types shared across all packages.

**Contents:**
```
MovingBoxCore/
├── Sources/
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── String+Extensions.swift
│   │   └── Collection+Extensions.swift
│   ├── Types/
│   │   ├── Result+Extensions.swift
│   │   ├── Identifier.swift          # Type-safe IDs
│   │   └── Money.swift               # Currency type
│   ├── Errors/
│   │   ├── AppError.swift
│   │   └── ErrorContext.swift
│   ├── Logging/
│   │   └── Logger.swift
│   └── Configuration/
│       ├── FeatureFlags.swift
│       └── BuildConfiguration.swift
└── Tests/
```

**Key Types:**
```swift
// Type-safe identifiers (avoid String/UUID confusion)
public struct Identifier<T>: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init() { rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

public typealias ItemID = Identifier<InventoryItemEntity>
public typealias LocationID = Identifier<LocationEntity>
public typealias LabelID = Identifier<LabelEntity>
public typealias HomeID = Identifier<HomeEntity>

// Money type for prices (avoid Double precision issues)
public struct Money: Hashable, Codable, Sendable {
    public let amount: Decimal
    public let currencyCode: String

    public static func usd(_ amount: Decimal) -> Money {
        Money(amount: amount, currencyCode: "USD")
    }
}
```

**Dependencies:** None (pure Swift)

---

### 2. Domain Layer (Business Logic)

#### 2.1 InventoryDomain

**Purpose:** Core business entities and rules for inventory management.

**Contents:**
```
InventoryDomain/
├── Sources/
│   ├── Entities/                     # Plain Swift structs (not SwiftData)
│   │   ├── InventoryItemEntity.swift
│   │   ├── LocationEntity.swift
│   │   ├── LabelEntity.swift
│   │   ├── HomeEntity.swift
│   │   └── InsurancePolicyEntity.swift
│   ├── ValueObjects/
│   │   ├── Dimensions.swift
│   │   ├── PhysicalAttributes.swift
│   │   ├── PurchaseInfo.swift
│   │   └── ImageReference.swift
│   ├── Aggregates/
│   │   └── InventoryAggregate.swift  # Item + relations
│   ├── Repositories/                  # Protocols only
│   │   ├── ItemRepository.swift
│   │   ├── LocationRepository.swift
│   │   ├── LabelRepository.swift
│   │   └── HomeRepository.swift
│   └── UseCases/
│       ├── CreateItemUseCase.swift
│       ├── UpdateItemUseCase.swift
│       ├── DeleteItemUseCase.swift
│       ├── SearchInventoryUseCase.swift
│       ├── CalculateInsuranceValueUseCase.swift
│       └── ValidateItemUseCase.swift
└── Tests/
```

**Key Types:**

```swift
// Pure Swift entity (no SwiftData, no dependencies)
public struct InventoryItemEntity: Identifiable, Hashable, Sendable {
    public let id: ItemID
    public var title: String
    public var quantity: Int
    public var description: String?
    public var price: Money?
    public var serialNumber: String?
    public var make: String?
    public var model: String?
    public var purchaseInfo: PurchaseInfo?
    public var physicalAttributes: PhysicalAttributes?
    public var imageReferences: [ImageReference]
    public var locationID: LocationID?
    public var labelIDs: Set<LabelID>
    public var homeID: HomeID?
    public var hasUsedAI: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(...) { ... }
}

// Repository protocol (implemented by Data layer)
public protocol ItemRepository: Sendable {
    func fetch(id: ItemID) async throws -> InventoryItemEntity?
    func fetchAll(in home: HomeID?) async throws -> [InventoryItemEntity]
    func fetchFiltered(_ filter: ItemFilter) async throws -> [InventoryItemEntity]
    func save(_ item: InventoryItemEntity) async throws
    func delete(id: ItemID) async throws
    func observe() -> AsyncStream<[InventoryItemEntity]>
}

// Use case (pure business logic)
public final class CreateItemUseCase: Sendable {
    private let itemRepository: ItemRepository
    private let validator: ItemValidator

    public init(itemRepository: ItemRepository, validator: ItemValidator) {
        self.itemRepository = itemRepository
        self.validator = validator
    }

    public func execute(_ request: CreateItemRequest) async throws -> InventoryItemEntity {
        try validator.validate(request)
        let item = InventoryItemEntity(
            id: ItemID(),
            title: request.title,
            // ... map request to entity
        )
        try await itemRepository.save(item)
        return item
    }
}
```

**Dependencies:** MovingBoxCore

#### 2.2 ExportDomain

**Purpose:** Business logic for data export/import.

**Contents:**
```
ExportDomain/
├── Sources/
│   ├── Entities/
│   │   ├── ExportManifest.swift
│   │   └── ImportResult.swift
│   ├── Protocols/
│   │   ├── ExportFormatter.swift    # CSV, JSON formatters
│   │   └── ImportParser.swift
│   └── UseCases/
│       ├── ExportInventoryUseCase.swift
│       └── ImportInventoryUseCase.swift
└── Tests/
```

**Dependencies:** MovingBoxCore, InventoryDomain

---

### 3. Data Layer (Persistence Abstraction)

#### 3.1 DataAbstractions

**Purpose:** Protocols that define how data is stored/retrieved, enabling SwiftData → SQLite swap.

**Contents:**
```
DataAbstractions/
├── Sources/
│   ├── Protocols/
│   │   ├── DataStore.swift           # Generic CRUD operations
│   │   ├── QuerySpecification.swift  # Query building
│   │   └── TransactionManager.swift  # Transaction support
│   ├── Types/
│   │   ├── DataQuery.swift
│   │   ├── SortDescriptor.swift
│   │   └── FetchResult.swift
│   └── Errors/
│       └── DataError.swift
└── Tests/
```

**Key Protocols:**

```swift
// Generic data store protocol (swap implementations)
public protocol DataStore: Sendable {
    associatedtype Entity: Identifiable

    func fetch(id: Entity.ID) async throws -> Entity?
    func fetchAll() async throws -> [Entity]
    func fetch(matching query: DataQuery<Entity>) async throws -> [Entity]
    func save(_ entity: Entity) async throws
    func save(_ entities: [Entity]) async throws
    func delete(id: Entity.ID) async throws
    func deleteAll(matching query: DataQuery<Entity>) async throws
    func observe() -> AsyncStream<[Entity]>
}

// Transaction support for batch operations
public protocol TransactionManager: Sendable {
    func performInTransaction<T>(_ work: @Sendable () async throws -> T) async throws -> T
}

// Query specification (type-safe queries)
public struct DataQuery<Entity> {
    public var predicate: Predicate<Entity>?
    public var sortDescriptors: [SortDescriptor<Entity>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?
}
```

**Dependencies:** MovingBoxCore

#### 3.2 SwiftDataProvider

**Purpose:** SwiftData implementation of DataAbstractions protocols.

**Contents:**
```
SwiftDataProvider/
├── Sources/
│   ├── Models/                       # @Model classes
│   │   ├── SDInventoryItem.swift     # SwiftData model
│   │   ├── SDLocation.swift
│   │   ├── SDLabel.swift
│   │   ├── SDHome.swift
│   │   └── SDInsurancePolicy.swift
│   ├── Mappers/                      # Entity ↔ Model conversion
│   │   ├── ItemMapper.swift
│   │   ├── LocationMapper.swift
│   │   └── LabelMapper.swift
│   ├── Repositories/                 # Protocol implementations
│   │   ├── SwiftDataItemRepository.swift
│   │   ├── SwiftDataLocationRepository.swift
│   │   ├── SwiftDataLabelRepository.swift
│   │   └── SwiftDataHomeRepository.swift
│   ├── Container/
│   │   ├── SwiftDataContainerManager.swift
│   │   └── ModelConfiguration+Extensions.swift
│   └── Migrations/
│       └── SchemaMigrations.swift
└── Tests/
```

**Key Implementation:**

```swift
// SwiftData model (internal to this package)
@Model
final class SDInventoryItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var quantity: Int
    var itemDescription: String?
    var priceAmount: Decimal?
    var priceCurrency: String?
    // ... other fields

    @Relationship var location: SDLocation?
    @Relationship var labels: [SDLabel]
    @Relationship var home: SDHome?
}

// Repository implementation
public final class SwiftDataItemRepository: ItemRepository {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetch(id: ItemID) async throws -> InventoryItemEntity? {
        let context = ModelContext(container)
        let uuid = id.rawValue
        let descriptor = FetchDescriptor<SDInventoryItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let model = try context.fetch(descriptor).first else {
            return nil
        }
        return ItemMapper.toEntity(model)
    }

    public func save(_ item: InventoryItemEntity) async throws {
        let context = ModelContext(container)
        let model = ItemMapper.toModel(item)
        context.insert(model)
        try context.save()
    }

    // ... other methods
}

// Mapper (bidirectional conversion)
enum ItemMapper {
    static func toEntity(_ model: SDInventoryItem) -> InventoryItemEntity {
        InventoryItemEntity(
            id: ItemID(rawValue: model.id),
            title: model.title,
            quantity: model.quantity,
            // ... map all fields
        )
    }

    static func toModel(_ entity: InventoryItemEntity) -> SDInventoryItem {
        SDInventoryItem(
            id: entity.id.rawValue,
            title: entity.title,
            // ... map all fields
        )
    }
}
```

**Dependencies:** MovingBoxCore, InventoryDomain, DataAbstractions

**Future SQLite Implementation:**
```
SQLiteProvider/        # Future package (same interfaces)
├── Sources/
│   ├── Schema/
│   │   └── SQLiteMigrations.swift
│   ├── Repositories/
│   │   ├── SQLiteItemRepository.swift
│   │   └── ...
│   └── Connection/
│       └── SQLiteConnectionManager.swift
```

#### 3.3 ImageStorage

**Purpose:** Image management abstracted from persistence layer.

**Contents:**
```
ImageStorage/
├── Sources/
│   ├── Protocols/
│   │   └── ImageStore.swift
│   ├── Types/
│   │   ├── ImageReference.swift
│   │   ├── ImageQuality.swift
│   │   └── ImageMetadata.swift
│   ├── Implementations/
│   │   ├── FileSystemImageStore.swift
│   │   ├── iCloudImageStore.swift
│   │   └── InMemoryImageStore.swift  # Testing
│   └── Managers/
│       ├── OptimizedImageManager.swift
│       └── ThumbnailGenerator.swift
└── Tests/
```

**Key Protocols:**

```swift
public protocol ImageStore: Sendable {
    func save(_ image: PlatformImage, for reference: ImageReference) async throws
    func load(_ reference: ImageReference) async throws -> PlatformImage?
    func loadThumbnail(_ reference: ImageReference) async throws -> PlatformImage?
    func delete(_ reference: ImageReference) async throws
    func exists(_ reference: ImageReference) async -> Bool
}

// Platform-agnostic image type
#if canImport(UIKit)
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
public typealias PlatformImage = NSImage
#endif
```

**Dependencies:** MovingBoxCore

---

### 4. Services Layer (External Integrations)

#### 4.1 AIService

**Purpose:** OpenAI/Vision API integration for item analysis.

**Contents:**
```
AIService/
├── Sources/
│   ├── Protocols/
│   │   └── AIAnalysisService.swift
│   ├── Types/
│   │   ├── AIAnalysisRequest.swift
│   │   ├── AIAnalysisResult.swift
│   │   ├── DetectedItem.swift
│   │   └── AIServiceError.swift
│   ├── Implementations/
│   │   ├── OpenAIService.swift
│   │   └── MockAIService.swift
│   └── Configuration/
│       └── AIServiceConfiguration.swift
└── Tests/
```

**Key Types:**

```swift
public protocol AIAnalysisService: Sendable {
    func analyzeSingleItem(image: Data) async throws -> AIAnalysisResult
    func analyzeMultipleItems(image: Data) async throws -> [DetectedItem]
}

public struct AIAnalysisResult: Sendable {
    public let suggestedTitle: String
    public let suggestedDescription: String?
    public let suggestedPrice: Money?
    public let suggestedCategory: String?
    public let confidence: Double
}

public struct DetectedItem: Identifiable, Sendable {
    public let id: UUID
    public let boundingBox: CGRect
    public let analysis: AIAnalysisResult
}
```

**Dependencies:** MovingBoxCore

#### 4.2 AnalyticsService

**Purpose:** Telemetry and analytics abstraction.

```
AnalyticsService/
├── Sources/
│   ├── Protocols/
│   │   └── AnalyticsTracker.swift
│   ├── Events/
│   │   ├── AnalyticsEvent.swift
│   │   └── InventoryEvents.swift
│   └── Implementations/
│       ├── TelemetryDeckTracker.swift
│       └── NullTracker.swift         # For testing/opt-out
└── Tests/
```

**Dependencies:** MovingBoxCore

#### 4.3 PurchaseService

**Purpose:** In-app purchase abstraction.

```
PurchaseService/
├── Sources/
│   ├── Protocols/
│   │   └── PurchaseManager.swift
│   ├── Types/
│   │   ├── SubscriptionStatus.swift
│   │   ├── PurchaseProduct.swift
│   │   └── EntitlementInfo.swift
│   └── Implementations/
│       ├── RevenueCatPurchaseManager.swift
│       └── MockPurchaseManager.swift
└── Tests/
```

**Dependencies:** MovingBoxCore

#### 4.4 SyncService

**Purpose:** Cloud sync abstraction (CloudKit now, could be custom later).

```
SyncService/
├── Sources/
│   ├── Protocols/
│   │   └── SyncManager.swift
│   ├── Types/
│   │   ├── SyncStatus.swift
│   │   └── SyncConflict.swift
│   └── Implementations/
│       ├── CloudKitSyncManager.swift
│       └── LocalOnlySyncManager.swift
└── Tests/
```

**Dependencies:** MovingBoxCore

---

### 5. UI Layer

#### 5.1 DesignSystem

**Purpose:** Reusable UI components, modifiers, and design tokens.

**Contents:**
```
DesignSystem/
├── Sources/
│   ├── Tokens/
│   │   ├── ColorTokens.swift
│   │   ├── TypographyTokens.swift
│   │   ├── SpacingTokens.swift
│   │   └── AnimationTokens.swift
│   ├── Components/
│   │   ├── Buttons/
│   │   │   ├── PrimaryButton.swift
│   │   │   └── SecondaryButton.swift
│   │   ├── Cards/
│   │   │   ├── ItemCard.swift
│   │   │   └── StatCard.swift
│   │   ├── Forms/
│   │   │   ├── FormField.swift
│   │   │   └── FormSection.swift
│   │   ├── Media/
│   │   │   ├── PhotoScrollView.swift
│   │   │   ├── PhotoPickerView.swift
│   │   │   └── ThumbnailView.swift
│   │   └── Feedback/
│   │       ├── LoadingView.swift
│   │       ├── EmptyStateView.swift
│   │       └── ConfettiView.swift
│   ├── Modifiers/
│   │   ├── CardStyle.swift
│   │   ├── PrimaryButtonStyle.swift
│   │   └── CustomModifiers.swift
│   └── Extensions/
│       └── View+Extensions.swift
└── Tests/
```

**Dependencies:** MovingBoxCore (for types like Money formatting)

---

### 6. Features Layer (MVVM Modules)

Each feature is self-contained with its own Views and ViewModels.

#### 6.1 Common Feature Structure

```
{Feature}Feature/
├── Sources/
│   ├── Public/
│   │   └── {Feature}Module.swift     # Public entry point
│   ├── Views/
│   │   ├── {Feature}RootView.swift
│   │   └── {SubView}View.swift
│   ├── ViewModels/
│   │   └── {Feature}ViewModel.swift
│   └── Internal/
│       └── {Feature}Coordinator.swift  # Internal navigation
└── Tests/
```

#### 6.2 InventoryFeature (Example)

```
InventoryFeature/
├── Sources/
│   ├── Public/
│   │   └── InventoryModule.swift
│   ├── Views/
│   │   ├── InventoryListView.swift
│   │   ├── InventoryDetailView.swift
│   │   ├── ItemCreationFlowView.swift
│   │   ├── BatchAnalysisView.swift
│   │   └── Components/
│   │       ├── ItemRow.swift
│   │       ├── LabelPicker.swift
│   │       └── LocationPicker.swift
│   └── ViewModels/
│       ├── InventoryListViewModel.swift
│       ├── InventoryDetailViewModel.swift
│       ├── ItemCreationViewModel.swift
│       └── BatchAnalysisViewModel.swift
└── Tests/
```

**MVVM Pattern:**

```swift
// ViewModel (owns business logic, uses UseCases)
@MainActor
@Observable
public final class InventoryListViewModel {
    // Published state
    public private(set) var items: [InventoryItemEntity] = []
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // Filter state
    public var searchText = ""
    public var selectedLocation: LocationID?
    public var selectedLabels: Set<LabelID> = []

    // Dependencies (injected)
    private let itemRepository: ItemRepository
    private let searchUseCase: SearchInventoryUseCase
    private let deleteUseCase: DeleteItemUseCase

    public init(
        itemRepository: ItemRepository,
        searchUseCase: SearchInventoryUseCase,
        deleteUseCase: DeleteItemUseCase
    ) {
        self.itemRepository = itemRepository
        self.searchUseCase = searchUseCase
        self.deleteUseCase = deleteUseCase
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await itemRepository.fetchAll(in: nil)
        } catch {
            self.error = error
        }
    }

    public func search() async {
        let filter = ItemFilter(
            searchText: searchText,
            locationID: selectedLocation,
            labelIDs: selectedLabels
        )
        do {
            items = try await searchUseCase.execute(filter)
        } catch {
            self.error = error
        }
    }

    public func delete(_ item: InventoryItemEntity) async {
        do {
            try await deleteUseCase.execute(item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error
        }
    }
}

// View (thin, declarative)
public struct InventoryListView: View {
    @State private var viewModel: InventoryListViewModel

    public init(viewModel: InventoryListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        List {
            ForEach(viewModel.items) { item in
                ItemRow(item: item)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.delete(item) }
                        }
                    }
            }
        }
        .searchable(text: $viewModel.searchText)
        .task { await viewModel.load() }
        .onChange(of: viewModel.searchText) { _, _ in
            Task { await viewModel.search() }
        }
    }
}
```

#### 6.3 Other Feature Packages

**DashboardFeature:**
- DashboardView, statistics cards
- DashboardViewModel (aggregates counts, values)

**LocationsFeature:**
- LocationsListView, EditLocationView
- LocationsViewModel

**SettingsFeature:**
- SettingsView, ExportView, ImportView
- SubscriptionSettingsView, HomeManagementView
- SettingsViewModel, ExportViewModel

**OnboardingFeature:**
- OnboardingFlow (all onboarding screens)
- OnboardingViewModel

---

## Dependency Injection Strategy

### Container Pattern

```swift
// In main app target
@MainActor
final class DependencyContainer {
    // Singletons
    lazy var modelContainer: ModelContainer = {
        // SwiftData setup
    }()

    lazy var imageStore: ImageStore = {
        FileSystemImageStore()
    }()

    // Repositories (protocol types)
    lazy var itemRepository: ItemRepository = {
        SwiftDataItemRepository(container: modelContainer)
    }()

    lazy var locationRepository: LocationRepository = {
        SwiftDataLocationRepository(container: modelContainer)
    }()

    // Services
    lazy var aiService: AIAnalysisService = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-Mock-OpenAI") {
            return MockAIService()
        }
        #endif
        return OpenAIService(configuration: .default)
    }()

    // Use Cases
    func makeCreateItemUseCase() -> CreateItemUseCase {
        CreateItemUseCase(
            itemRepository: itemRepository,
            validator: ItemValidator()
        )
    }

    // ViewModels
    func makeInventoryListViewModel() -> InventoryListViewModel {
        InventoryListViewModel(
            itemRepository: itemRepository,
            searchUseCase: SearchInventoryUseCase(repository: itemRepository),
            deleteUseCase: DeleteItemUseCase(repository: itemRepository)
        )
    }
}
```

### App Entry Point

```swift
@main
struct MovingBoxApp: App {
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dependencyContainer, container)
        }
    }
}

// Environment key for DI
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
```

---

## Migration Strategy

### Phase 1: Foundation (Week 1-2)

**Goal:** Create package structure and Core package.

1. Create `Packages/` directory structure
2. Create `MovingBoxCore` package
   - Move extensions, utilities, Logger
   - Define Identifier types, Money type
   - Extract FeatureFlags, BuildConfiguration
3. Update main target to depend on MovingBoxCore
4. Verify build succeeds

**Deliverables:**
- [ ] `Packages/Core/MovingBoxCore` package
- [ ] Main app compiles with Core dependency

### Phase 2: Domain Layer (Week 3-4)

**Goal:** Extract business entities and define repository protocols.

1. Create `InventoryDomain` package
   - Define InventoryItemEntity (plain struct)
   - Define LocationEntity, LabelEntity, HomeEntity
   - Define repository protocols (ItemRepository, etc.)
   - Create basic use cases
2. Create `ExportDomain` package
   - Export/Import use cases

**Deliverables:**
- [ ] `Packages/Domain/InventoryDomain` package
- [ ] `Packages/Domain/ExportDomain` package
- [ ] All entity types defined as plain Swift structs

### Phase 3: Data Abstraction (Week 5-6)

**Goal:** Create persistence abstraction layer.

1. Create `DataAbstractions` package
   - DataStore protocol
   - Query types
2. Create `SwiftDataProvider` package
   - SwiftData @Model classes (renamed with SD prefix)
   - Mappers (Entity ↔ Model)
   - Repository implementations
   - Container manager
3. Create `ImageStorage` package
   - ImageStore protocol
   - FileSystemImageStore implementation
   - Move OptimizedImageManager

**Deliverables:**
- [ ] `Packages/Data/DataAbstractions` package
- [ ] `Packages/Data/SwiftDataProvider` package
- [ ] `Packages/Data/ImageStorage` package
- [ ] All data access through repository protocols

### Phase 4: Services (Week 7-8)

**Goal:** Extract external service integrations.

1. Create `AIService` package
   - Move OpenAIService
   - Define AIAnalysisService protocol
   - Create MockAIService
2. Create `AnalyticsService` package
   - Move TelemetryManager
   - Define AnalyticsTracker protocol
3. Create `PurchaseService` package
   - Move RevenueCatManager
   - Define PurchaseManager protocol
4. Create `SyncService` package
   - CloudKit abstraction

**Deliverables:**
- [ ] `Packages/Services/AIService` package
- [ ] `Packages/Services/AnalyticsService` package
- [ ] `Packages/Services/PurchaseService` package
- [ ] `Packages/Services/SyncService` package

### Phase 5: Design System (Week 9)

**Goal:** Extract reusable UI components.

1. Create `DesignSystem` package
   - Move shared components (ConfettiView, etc.)
   - Move custom modifiers
   - Define design tokens
   - Move UIConstants

**Deliverables:**
- [ ] `Packages/UI/DesignSystem` package
- [ ] All shared UI components extracted

### Phase 6: Features (Week 10-12)

**Goal:** Convert views to feature modules with MVVM.

1. Create `InventoryFeature` package
   - Move Item views
   - Create ItemListViewModel, ItemDetailViewModel
   - Create ItemCreationViewModel
2. Create `LocationsFeature` package
3. Create `DashboardFeature` package
4. Create `SettingsFeature` package
5. Create `OnboardingFeature` package

**Deliverables:**
- [ ] `Packages/Features/InventoryFeature` package
- [ ] `Packages/Features/LocationsFeature` package
- [ ] `Packages/Features/DashboardFeature` package
- [ ] `Packages/Features/SettingsFeature` package
- [ ] `Packages/Features/OnboardingFeature` package
- [ ] All views using proper MVVM pattern

### Phase 7: Integration & Cleanup (Week 13)

**Goal:** Final integration and cleanup.

1. Set up dependency injection container
2. Configure navigation between features
3. Remove old code from main target
4. Update tests
5. Documentation

**Deliverables:**
- [ ] DependencyContainer configured
- [ ] All tests passing
- [ ] Main target is thin shell

---

## Package.swift Templates

### Workspace Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MovingBoxPackages",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Core
        .library(name: "MovingBoxCore", targets: ["MovingBoxCore"]),

        // Domain
        .library(name: "InventoryDomain", targets: ["InventoryDomain"]),
        .library(name: "ExportDomain", targets: ["ExportDomain"]),

        // Data
        .library(name: "DataAbstractions", targets: ["DataAbstractions"]),
        .library(name: "SwiftDataProvider", targets: ["SwiftDataProvider"]),
        .library(name: "ImageStorage", targets: ["ImageStorage"]),

        // Services
        .library(name: "AIService", targets: ["AIService"]),
        .library(name: "AnalyticsService", targets: ["AnalyticsService"]),
        .library(name: "PurchaseService", targets: ["PurchaseService"]),
        .library(name: "SyncService", targets: ["SyncService"]),

        // UI
        .library(name: "DesignSystem", targets: ["DesignSystem"]),

        // Features
        .library(name: "DashboardFeature", targets: ["DashboardFeature"]),
        .library(name: "InventoryFeature", targets: ["InventoryFeature"]),
        .library(name: "LocationsFeature", targets: ["LocationsFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.0.0"),
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK.git", from: "2.0.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "8.0.0"),
        .package(url: "https://github.com/liveview-native/liveview-native-core-swift.git", from: "0.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    ],
    targets: [
        // Core
        .target(
            name: "MovingBoxCore",
            dependencies: []
        ),
        .testTarget(name: "MovingBoxCoreTests", dependencies: ["MovingBoxCore"]),

        // Domain
        .target(
            name: "InventoryDomain",
            dependencies: ["MovingBoxCore"]
        ),
        .target(
            name: "ExportDomain",
            dependencies: ["MovingBoxCore", "InventoryDomain"]
        ),

        // Data
        .target(
            name: "DataAbstractions",
            dependencies: ["MovingBoxCore"]
        ),
        .target(
            name: "SwiftDataProvider",
            dependencies: ["MovingBoxCore", "InventoryDomain", "DataAbstractions"]
        ),
        .target(
            name: "ImageStorage",
            dependencies: ["MovingBoxCore"]
        ),

        // Services
        .target(
            name: "AIService",
            dependencies: ["MovingBoxCore"]
        ),
        .target(
            name: "AnalyticsService",
            dependencies: ["MovingBoxCore", .product(name: "TelemetryDeck", package: "SwiftSDK")]
        ),
        .target(
            name: "PurchaseService",
            dependencies: ["MovingBoxCore", .product(name: "RevenueCat", package: "purchases-ios")]
        ),
        .target(
            name: "SyncService",
            dependencies: ["MovingBoxCore"]
        ),

        // UI
        .target(
            name: "DesignSystem",
            dependencies: ["MovingBoxCore"]
        ),

        // Features
        .target(
            name: "DashboardFeature",
            dependencies: [
                "MovingBoxCore",
                "InventoryDomain",
                "DesignSystem"
            ]
        ),
        .target(
            name: "InventoryFeature",
            dependencies: [
                "MovingBoxCore",
                "InventoryDomain",
                "DataAbstractions",
                "AIService",
                "ImageStorage",
                "DesignSystem"
            ]
        ),
        .target(
            name: "LocationsFeature",
            dependencies: [
                "MovingBoxCore",
                "InventoryDomain",
                "DesignSystem"
            ]
        ),
        .target(
            name: "SettingsFeature",
            dependencies: [
                "MovingBoxCore",
                "InventoryDomain",
                "ExportDomain",
                "PurchaseService",
                "SyncService",
                "DesignSystem"
            ]
        ),
        .target(
            name: "OnboardingFeature",
            dependencies: [
                "MovingBoxCore",
                "InventoryDomain",
                "DesignSystem"
            ]
        ),
    ]
)
```

---

## Benefits of This Architecture

### 1. Faster Builds
- Incremental builds only recompile changed packages
- Parallel compilation of independent packages
- ~60-70% faster clean builds typical

### 2. Better Testability
- Pure domain logic tested without UI
- Mock implementations for all protocols
- Repository tests with in-memory stores

### 3. Easy Persistence Swap
```swift
// Current (SwiftData)
let container = DependencyContainer(
    itemRepository: SwiftDataItemRepository(container: modelContainer)
)

// Future (SQLite)
let container = DependencyContainer(
    itemRepository: SQLiteItemRepository(connection: sqliteConnection)
)
```

### 4. Code Sharing
Convert any package to remote:
```swift
// Local
.package(path: "../Packages/InventoryDomain")

// Remote
.package(url: "https://github.com/yourorg/inventory-domain.git", from: "1.0.0")
```

### 5. Clear Boundaries
- Domain logic has no UI dependencies
- UI has no persistence dependencies
- Services are interchangeable

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Large initial effort | Phase-based approach, can pause between phases |
| Breaking changes | Extensive test coverage before migration |
| SwiftData + CloudKit complexity | Keep SwiftData models in dedicated package |
| Team learning curve | Document patterns, create examples |
| Navigation complexity | Keep Router in main app initially |

---

## Success Metrics

1. **Build time reduction:** Target 50%+ faster incremental builds
2. **Test coverage:** Each package has 80%+ coverage
3. **Decoupling:** Domain/Data layers have 0 UIKit/SwiftUI imports
4. **Feature isolation:** Each feature compiles independently

---

## Next Steps

1. **Review and approve plan**
2. **Create feature branch:** `feature/modular-packages`
3. **Start Phase 1:** MovingBoxCore package
4. **Iterate through phases**

---

## Appendix: Current vs. Target Structure Comparison

### Current Structure
```
MovingBox/
├── Models/          # SwiftData + business logic mixed
├── Services/        # Singletons, tight coupling
├── ViewModels/      # Sparse (2 files)
├── Views/           # Direct @Query, heavy business logic
└── Configuration/
```

### Target Structure
```
Packages/
├── Core/            # Pure utilities
├── Domain/          # Business logic (no persistence)
├── Data/            # Persistence abstraction + implementations
├── Services/        # External integrations
├── UI/              # Reusable components
└── Features/        # Self-contained MVVM modules

MovingBox/           # Thin shell
├── App/             # Entry, DI, navigation
└── Resources/
```
