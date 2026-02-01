# SwiftData → sqlite-data Migration Plan

## Executive Summary

**Effort Estimate**: 2-3 weeks of focused development + 1 week testing
**Complexity**: High (architectural change + CloudKit sharing implementation)
**Risk Level**: Medium (small user base, automatic migration possible)
**Primary Benefit**: Enables true collaborative family sharing + better MVVM architecture

---

## Migration Goals

1. **Enable iCloud Family Sharing**: Allow multiple family members to collaborate on the same inventory with real-time sync
2. **Improve MVVM Architecture**: Move query logic from views to ViewModels for better separation of concerns
3. **Seamless User Experience**: Automatic migration on first launch with no manual export/import required

---

## Migration Scope

### Current State Analysis

**Models**: 5 SwiftData models (159 total Swift files)
- `InventoryItem` (most complex - 30+ properties)
- `InventoryLocation`
- `InventoryLabel` (uses custom `UIColorValueTransformer`)
- `Home`
- `InsurancePolicy`

**SwiftData Usage**:
- 18 files using `@Query`
- 22 files using `FetchDescriptor`
- 40 files with insert/delete/save operations
- 1 explicit `@Relationship` (InsurancePolicy ↔ Home)
- Implicit relationships via optional references

**Key Patterns**:
- External image storage via `OptimizedImageManager` ✅ (compatible)
- `PhotoManageable` protocol with async image loading ✅ (compatible)
- Complex migration system for legacy `@Attribute(.externalStorage)` data
- `ModelContainerManager` for container lifecycle

---

## Phase 1: Schema & Model Conversion (3-4 days)

### 1.1 Define sqlite-data Table Schemas

Convert `@Model` classes → `@Table` structs:

**Key Changes**:
- `class` → `struct` (value semantics)
- Remove `ObservableObject` conformance
- Remove `@Published` properties
- Define explicit foreign key relationships
- Handle `UIColor` differently (store as hex string)

**Example Transformation**:
```swift
// BEFORE (SwiftData)
@Model
final class InventoryItem: ObservableObject {
    var title: String = ""
    var location: InventoryLocation?
    // ...
}

// AFTER (sqlite-data)
@Table
struct InventoryItem {
    @Column(primaryKey: .autoincrement)
    var id: Int64?

    var title: String = ""
    var locationID: Int64? // Foreign key
    // ...
}
```

**UIColor Handling**:
```swift
// Store as hex string instead of transformable
var colorHex: String? // "#FF5733"

// Add computed property for SwiftUI
var color: Color? {
    guard let hex = colorHex else { return nil }
    return Color(hex: hex)
}
```

### 1.2 Define Relationships

sqlite-data uses foreign keys instead of SwiftData's automatic relationships:

- `InventoryItem.locationID` → `InventoryLocation.id`
- `InventoryItem.labelID` → `InventoryLabel.id`
- `Home.insurancePolicyID` → `InsurancePolicy.id`

### 1.3 Update PhotoManageable Protocol

Change from `AnyObject` to work with structs:
```swift
protocol PhotoManageable {  // Remove: AnyObject constraint
    var imageURL: URL? { get set }
    // ... rest stays same
}
```

**Effort**: 3-4 days
**Risks**:
- UIColor conversion may lose fidelity (test thoroughly)
- Relationship mapping must be carefully validated
- Struct semantics require different mental model

---

## Phase 2: Data Migration System (4-5 days)

### 2.1 Create Migration Coordinator

Build system to:
1. Detect if migration needed (check for old SwiftData store)
2. Read all data from SwiftData `ModelContainer`
3. Create sqlite-data `DatabaseQueue` with schema
4. Transform and insert all records
5. Preserve relationships via ID mapping
6. Validate migration success
7. Archive old SwiftData store (don't delete)

### 2.2 Migration Logic

**Order matters** (due to foreign key constraints):
1. Migrate `InventoryLabel` (no dependencies)
2. Migrate `InventoryLocation` (no dependencies)
3. Migrate `InsurancePolicy` (no dependencies)
4. Migrate `Home` (references InsurancePolicy)
5. Migrate `InventoryItem` (references Location & Label)

**ID Mapping**:
```swift
var swiftDataIDToSQLiteID: [PersistentIdentifier: Int64] = [:]
```

### 2.3 Progress UI

Update `ModelContainerManager` migration UI:
- "Upgrading to new storage system..."
- Progress bar for each model type
- Rollback on failure

### 2.4 Testing Strategy

Create test migrations with:
- Empty database
- Small dataset (10 items)
- Large dataset (1000+ items)
- Complex relationships
- Edge cases (nil values, empty strings)
- Legacy image data still in `@Attribute(.externalStorage)`

**Effort**: 4-5 days
**Risks**:
- Migration bugs could corrupt user data (extensive testing critical)
- Large databases may take time (need progress reporting)
- Rollback strategy needed if migration fails

---

## Phase 3: Query Refactoring (3-4 days)

### 3.1 Replace @Query with @FetchAll/@FetchOne

**Before**:
```swift
struct DashboardView: View {
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Query private var items: [InventoryItem]
    // ...
}
```

**After**:
```swift
struct DashboardView: View {
    @FetchAll(
        ordering: .asc(\.purchaseDate),
        database: \.database
    )
    private var homes: [Home]

    @FetchAll(database: \.database)
    private var items: [InventoryItem]
    // ...
}
```

### 3.2 Move Logic to ViewModels

This addresses your MVVM goal - queries can now live in `ObservableObject` ViewModels:

```swift
@MainActor
@Observable
class DashboardViewModel {
    @FetchAll(database: \.database)
    var items: [InventoryItem]

    @FetchAll(
        ordering: .desc(\.createdAt),
        database: \.database
    )
    var recentItems: [InventoryItem]

    var totalValue: Decimal {
        items.reduce(0) { $0 + ($1.price * Decimal($1.quantityInt)) }
    }
}
```

### 3.3 Update Filtering & Sorting

**Before** (SwiftData):
```swift
@Query(filter: #Predicate<InventoryItem> { item in
    item.location?.name == locationName
}) var items: [InventoryItem]
```

**After** (sqlite-data):
```swift
@FetchAll(
    where: { $0.locationID == locationID },
    database: \.database
)
var items: [InventoryItem]
```

**Effort**: 3-4 days (18 @Query files + logic extraction)
**Risks**:
- Complex predicates may need SQL knowledge
- Breaking change to view architecture

---

## Phase 4: CloudKit Family Sharing (5-7 days) ⚠️ **MOST COMPLEX**

### 4.1 Configure SyncEngine

**Update App Entry Point**:
```swift
@main
struct MovingBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .database(
            .file(URL(/* ... */)),
            sync: .cloudKit(
                .init(
                    containerIdentifier: "iCloud.com.yourapp.MovingBox"
                )
            )
        )
    }
}
```

### 4.2 Implement CloudKit Sharing

sqlite-data has **full CKShare support** for collaborative sharing ([source](https://www.pointfree.co/blog/posts/184-sqlitedata-1-0-an-alternative-to-swiftdata-with-cloudkit-sync-and-sharing)):

**Sharing UI** (add to Home/Location views):
```swift
Button("Share with Family") {
    // Create CKShare for this record
    try await database.share(home)
}
.cloudSharingView(for: home)
```

### 4.3 Permissions & Participant Management

- Owner: Full read/write access
- Participants: Configurable (read-only or read/write)
- Handle invitation acceptance
- Display participant list
- Remove participants

### 4.4 Conflict Resolution

sqlite-data handles this automatically, but you need to:
- Test concurrent edits from multiple devices
- Verify last-write-wins behavior is acceptable
- Add UI feedback for sync status

### 4.5 Testing Requirements

**Critical**: Test with actual family sharing:
- Create share invitation
- Accept on second device/account
- Edit from both simultaneously
- Test offline → online sync
- Test participant removal
- Test share deletion

**Effort**: 5-7 days
**Risks**:
- CloudKit sharing is inherently complex
- Requires multiple Apple IDs for testing
- Sync conflicts need careful handling
- Family Sharing entitlement setup required

---

## Phase 5: Dependency Injection Refactoring (2-3 days)

### 5.1 Remove ModelContext Environment

**Before**:
```swift
@Environment(\.modelContext) var modelContext
modelContext.insert(item)
modelContext.delete(item)
try modelContext.save()
```

**After**:
```swift
@Environment(\.database) var database
try database.insert(item)
try database.delete(item)
// No explicit save needed
```

### 5.2 Update ModelContainerManager

Replace `ModelContainer` with `DatabaseQueue`:
```swift
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    let database: DatabaseQueue

    init() {
        self.database = try! DatabaseQueue(/* config */)
    }
}
```

**Effort**: 2-3 days
**Risks**: Many files touch modelContext (40 files)

---

## Phase 6: Test Suite Refactoring (3-4 days)

### 6.1 Update Test Utilities

**Before**:
```swift
let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: schema, configurations: [configuration])
```

**After**:
```swift
let database = DatabaseQueue(path: ":memory:")
try database.migrate(/* schema */)
```

### 6.2 Update Test Files

Refactor all test files:
- SnapshotTests.swift
- DataManagerTests.swift
- HomeMigrationTests.swift
- 20+ other test files

**Effort**: 3-4 days
**Risks**: Test coverage may temporarily drop during refactor

---

## Phase 7: UI & Polish (2-3 days)

### 7.1 Family Sharing UI

Add new views:
- Share management screen
- Participant list
- Invitation acceptance flow
- Sync status indicator

### 7.2 Settings Updates

- iCloud sync toggle (already exists)
- Family sharing toggle
- "Who has access" viewer
- Share link generation

### 7.3 Onboarding

Update if needed to explain family sharing feature

**Effort**: 2-3 days

---

## Critical Issues & Risks

### 🔴 **High Risk**

1. **CloudKit Family Sharing Complexity**
   - This is the most complex part by far
   - Requires extensive testing with multiple Apple IDs
   - See [Point-Free Episode #343](https://www.pointfree.co/episodes/ep343-cloudkit-sync-sharing) for implementation details
   - Budget extra time for this

2. **Data Migration**
   - Migration bugs = data loss for users
   - Requires extensive testing with production-like data
   - Need rollback strategy
   - Consider beta testing with willing users first

3. **PersistentIdentifier → Int64 ID Mapping**
   - SwiftData uses `PersistentIdentifier`, sqlite-data uses `Int64`
   - Any code storing/comparing IDs needs updating
   - Selection state in `InventoryListView` uses `Set<PersistentIdentifier>`

### 🟡 **Medium Risk**

4. **UIColor Transformation**
   - Current: `@Attribute(.transformable(by: UIColorValueTransformer.self))`
   - New: Store hex string, parse on access
   - May lose color space fidelity
   - Test with all existing label colors

5. **Reference vs Value Semantics**
   - SwiftData models are classes (reference semantics)
   - sqlite-data uses structs (value semantics)
   - Any code assuming reference behavior will break
   - `PhotoManageable` protocol currently requires `AnyObject`

6. **Relationship Queries**
   - SwiftData: `item.location?.name`
   - sqlite-data: Need join or separate fetch
   - May impact performance if not optimized

### 🟢 **Low Risk**

7. **Image Storage**
   - Already using external `OptimizedImageManager` ✅
   - URLs just need to be preserved during migration

8. **Library Maturity**
   - sqlite-data is relatively new (1.0 released recently)
   - Point-Free has good track record
   - Only 8 paying users = low production risk

---

## Migration Testing Strategy

### Pre-Release Testing

1. **Unit Tests**: All models, migrations, queries
2. **Integration Tests**: Full migration with realistic data
3. **UI Tests**: Sharing flows, conflict scenarios
4. **Beta Testing**: 2-3 willing users (export backup first!)
5. **Staging Environment**: Test with TestFlight before prod

### Migration Validation

Create validation suite that checks:
- Record counts match (SwiftData count == sqlite-data count)
- Relationships preserved (all foreign keys valid)
- No data loss (sample records verified)
- Images accessible (URLs valid)
- Colors preserved (hex conversion accurate)

---

## Recommended Approach

Given the complexity, I recommend a **phased rollout**:

### Phase A: Core Migration (Week 1-2)
- Model conversion
- Data migration system
- Query refactoring
- Basic sqlite-data working without CloudKit

### Phase B: CloudKit Sync (Week 2-3)
- Enable basic CloudKit sync (private database)
- Test multi-device sync for single user
- Validate data integrity

### Phase C: Family Sharing (Week 3-4)
- Implement CKShare support
- Build sharing UI
- Test collaborative editing
- Handle edge cases

### Phase D: Testing & Polish (Week 4-5)
- Beta testing with real users
- Bug fixes
- Performance optimization
- Documentation updates

---

## Alternatives Considered

1. **Stay with SwiftData + NSPersistentCloudKitContainer**
   - Pro: Less work
   - Con: Family sharing still not possible, MVVM issues remain

2. **Core Data + CloudKit**
   - Pro: More mature, better documented
   - Con: More boilerplate, legacy API, similar MVVM issues

3. **Custom CloudKit Implementation**
   - Pro: Full control
   - Con: Months of work, reinventing the wheel

**Verdict**: sqlite-data is the right choice given your goals.

---

## Timeline Summary

| Phase | Effort | Priority |
|-------|--------|----------|
| 1. Schema Conversion | 3-4 days | High |
| 2. Data Migration | 4-5 days | Critical |
| 3. Query Refactoring | 3-4 days | High |
| 4. CloudKit Sharing | 5-7 days | Critical |
| 5. DI Refactoring | 2-3 days | Medium |
| 6. Test Suite | 3-4 days | High |
| 7. UI Polish | 2-3 days | Medium |
| **Total** | **22-30 days** | - |

**With testing & contingency**: **4-6 weeks**

---

## Next Steps

Recommended implementation order:

1. **Start with POC**: Convert one model (`InventoryLabel`) to validate approach
2. **Build migration for that one model**: Prove data migration works
3. **Implement basic CloudKit sync**: Validate sync works before sharing
4. **Add family sharing**: Last, as it's most complex

---

## Resources

**sqlite-data Documentation & Articles**:
- [SQLiteData 1.0: CloudKit sync and sharing](https://www.pointfree.co/blog/posts/184-sqlitedata-1-0-an-alternative-to-swiftdata-with-cloudkit-sync-and-sharing)
- [SQLiteData Documentation - CloudKit Sharing](https://swiftpackageindex.com/pointfreeco/sqlite-data/1.3.0/documentation/sqlitedata/cloudkitsharing)
- [Point-Free Episode #343: CloudKit Sync - Sharing](https://www.pointfree.co/episodes/ep343-cloudkit-sync-sharing)
- [GitHub Repository](https://github.com/pointfreeco/sqlite-data)

**Apple CloudKit Resources**:
- [Get the most out of CloudKit Sharing - Tech Talks](https://developer.apple.com/videos/play/tech-talks/10874/)

---

## Decision Log

**Date**: 2026-01-06
**Decision**: Migrate from SwiftData to sqlite-data
**Rationale**:
- Enable collaborative family sharing (primary goal)
- Improve MVVM architecture by allowing queries in ViewModels
- Small user base (8 paying users) reduces migration risk
- Automatic migration on first launch provides seamless UX

**Key Constraints**:
- Must preserve all existing user data
- No manual export/import process
- Release when ready (no hard deadline)
- Comfortable with SQLite management
