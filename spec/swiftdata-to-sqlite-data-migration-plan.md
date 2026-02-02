# SwiftData → sqlite-data Migration Plan

## Executive Summary

**Complexity**: High (architectural change + data migration + CloudKit sharing)
**Risk Level**: Medium (small user base, automatic migration, rollback strategy)
**Primary Benefit**: Enables true collaborative family sharing + better MVVM architecture
**Strategy**: Single release — migrate directly from SwiftData's SQLite store to sqlite-data using raw SQLite reads (no intermediate SwiftData schema migration)

---

## Migration Goals

1. **Enable iCloud Family Sharing**: Allow multiple family members to collaborate on the same inventory with real-time sync
2. **Improve MVVM Architecture**: Move query logic from views to ViewModels for better separation of concerns
3. **Seamless User Experience**: Automatic migration on first launch with no manual export/import required
4. **Skip-proof**: Users upgrading from any prior version get a clean migration in one step

---

## Migration Scope

### Current State Analysis

**Models**: 5 SwiftData models
- `InventoryItem` (most complex - 30+ properties)
- `InventoryLocation`
- `InventoryLabel` (uses custom `UIColorValueTransformer`)
- `Home`
- `InsurancePolicy`

**Relationships** (9 total across 5 models):
- `InventoryItem.labels` → `[InventoryLabel]` (many-to-many, join table)
- `InventoryItem.location` → `InventoryLocation?` (to-one FK)
- `InventoryItem.home` → `Home?` (to-one FK)
- `InventoryLabel.inventoryItems` → `[InventoryItem]` (inverse of labels)
- `InventoryLocation.inventoryItems` → `[InventoryItem]?` (inverse)
- `InventoryLocation.home` → `Home?` (to-one FK)
- `Home.insurancePolicies` → `[InsurancePolicy]` (many-to-many, join table)
- `Home.items` → `[InventoryItem]?` (inverse of item.home)
- `Home.locations` → `[InventoryLocation]?` (inverse of location.home)
- `InsurancePolicy.insuredHomes` → `[Home]` (inverse of insurancePolicies)

**SwiftData Usage**:
- 27 files using `@Query`
- 15 files using `FetchDescriptor`
- 27 files with `modelContext` insert/delete/save operations

**Key Patterns**:
- External image storage via `OptimizedImageManager` (compatible)
- `PhotoManageable` protocol with async image loading (compatible)
- Legacy `@Attribute(.externalStorage)` image migration system
- `ModelContainerManager` singleton for container lifecycle
- `RelationshipMigrationHelper` for raw SQLite FK capture (reusable)

### Production Schema Versions Users May Have

Users upgrading may have one of two SQLite schemas:

**v2.1.0 schema** (to-one relationships):
- `ZINVENTORYITEM.ZLABEL` — FK to `ZINVENTORYLABEL.Z_PK`
- `ZHOME.ZINSURANCEPOLICY` — FK to `ZINSURANCEPOLICY.Z_PK`
- `ZINVENTORYLABEL.ZHOME` — FK to `ZHOME.Z_PK`

**Post-multi-home-cleanup schema** (to-many relationships):
- `Z_2LABELS` join table — `Z_2INVENTORYITEMS`, `Z_3LABELS` columns
- `Z_1INSURANCEPOLICIES` join table — `Z_1HOMES`, `Z_2INSURANCEPOLICIES` columns
- Old FK columns dropped

The raw SQLite migration approach handles both schemas by checking column/table existence dynamically.

---

## Migration Strategy: Raw SQLite Bridge

Instead of reading through SwiftData's `ModelContainer` APIs, the migration reads directly from SwiftData's underlying SQLite database. This approach:

1. **Handles any schema version** — dynamically checks for old FK columns vs. join tables
2. **Avoids SwiftData initialization issues** — no need to create a `ModelContainer` for the old schema
3. **Reuses proven code** — extends `RelationshipMigrationHelper`'s raw SQLite patterns
4. **Is skip-proof** — works whether the user is on v2.1.0 or any intermediate version

### Migration Flow

```
App Launch
    │
    ├─ Fresh install? → Create sqlite-data database directly, done
    │
    └─ Existing SwiftData store detected?
        │
        ├─ 1. Open old .store file with sqlite3 (read-only)
        ├─ 2. Read all rows from Core Data tables (ZINVENTORYITEM, etc.)
        ├─ 3. Detect relationship format (old FKs vs join tables)
        ├─ 4. Build complete object graph in memory
        ├─ 5. Create sqlite-data DatabaseQueue
        ├─ 6. Write all records with proper relationships
        ├─ 7. Validate record counts match
        ├─ 8. Archive old .store file (don't delete)
        └─ 9. Mark migration complete in UserDefaults
```

---

## Phase 1: Schema & Model Conversion (3-4 days)

### 1.1 Define sqlite-data Table Schemas

Convert `@Model` classes → `@Table` structs:

**Key Changes**:
- `class` → `struct` (value semantics)
- Remove `ObservableObject` conformance
- Remove `@Published` properties
- Define explicit foreign key columns
- Handle `UIColor` differently (store as hex string)
- Many-to-many relationships use explicit join tables

**Example Transformation**:
```swift
// BEFORE (SwiftData)
@Model
final class InventoryItem: ObservableObject {
    var title: String = ""
    var location: InventoryLocation?
    var labels: [InventoryLabel] = []
    // ...
}

// AFTER (sqlite-data)
@Table
struct InventoryItem {
    @Column(primaryKey: .autoincrement)
    var id: Int64?

    var title: String = ""
    var locationID: Int64? // Foreign key
    // labels handled via join table
    // ...
}

// Join table for many-to-many
@Table
struct InventoryItemLabel {
    @Column(primaryKey: .autoincrement)
    var id: Int64?

    var inventoryItemID: Int64
    var inventoryLabelID: Int64
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

sqlite-data uses foreign keys and join tables:

**To-one relationships** (FK columns):
- `InventoryItem.locationID` → `InventoryLocation.id`
- `InventoryItem.homeID` → `Home.id`
- `InventoryLocation.homeID` → `Home.id`

**Many-to-many relationships** (join tables):
- `InventoryItemLabel` — links `InventoryItem` ↔ `InventoryLabel`
- `HomeInsurancePolicy` — links `Home` ↔ `InsurancePolicy`

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

## Phase 2: Data Migration System (5-6 days)

### 2.1 Create SQLiteMigrationCoordinator

Build a migration coordinator that reads directly from SwiftData's SQLite store:

```swift
@MainActor
struct SQLiteMigrationCoordinator {

    /// Migrate from SwiftData's SQLite store to sqlite-data DatabaseQueue
    static func migrateIfNeeded(to database: DatabaseQueue) -> MigrationResult {
        let dbPath = appSupportURL.appendingPathComponent("default.store").path

        guard FileManager.default.fileExists(atPath: dbPath) else {
            return .freshInstall // No old database
        }

        guard !isMigrationCompleted else {
            return .alreadyCompleted
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return .error("Failed to open old database")
        }
        defer { sqlite3_close(db) }

        // Read all data from old schema
        let labels = readLabels(db: db)
        let locations = readLocations(db: db)
        let policies = readInsurancePolicies(db: db)
        let homes = readHomes(db: db)
        let items = readInventoryItems(db: db)
        let relationships = readRelationships(db: db) // FKs or join tables

        // Write to sqlite-data
        try database.write { tx in
            // Insert in dependency order
            // Map old Z_PK → new Int64 IDs
            // Create join table entries for many-to-many
        }

        // Validate
        // Archive old store
        // Mark complete
    }
}
```

### 2.2 Reading from SwiftData's SQLite Schema

SwiftData (via Core Data) uses these naming conventions:
- Tables: `Z` + uppercase model name (e.g., `ZINVENTORYITEM`)
- Columns: `Z` + uppercase property name (e.g., `ZTITLE`, `ZPRICE`)
- Primary key: `Z_PK` (integer, auto-increment)
- FK columns: `Z` + uppercase relationship name (e.g., `ZLOCATION`)
- Join tables: `Z_` + index + relationship name (e.g., `Z_2LABELS`)
- Metadata: `Z_PRIMARYKEY`, `Z_METADATA`, `Z_MODELCACHE`

**Key column mappings per model:**

| SwiftData Property | SQLite Column | Type |
|---|---|---|
| `InventoryItem.title` | `ZTITLE` | TEXT |
| `InventoryItem.price` | `ZPRICE` | REAL (NSDecimalNumber) |
| `InventoryItem.createdAt` | `ZCREATEDAT` | REAL (TimeInterval since 2001-01-01) |
| `InventoryItem.id` | `ZID` | TEXT (UUID string, may be NULL for pre-ID-stabilization rows) |
| `InventoryLabel.name` | `ZNAME` | TEXT |
| `InventoryLabel.color` | `ZCOLOR` | BLOB (UIColorValueTransformer) |
| `Home.name` | `ZNAME` | TEXT |
| `Home.isPrimary` | `ZISPRIMARY` | INTEGER (0/1) |

### 2.3 Handling Both Schema Versions

The migration must detect and handle both old and new relationship formats:

```swift
/// Detect whether old FK columns or new join tables exist
static func readRelationships(db: OpaquePointer?) -> RelationshipData {
    // Check for old FK columns (v2.1.0 schema)
    let hasOldLabelFK = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZLABEL")
    let hasOldInsuranceFK = columnExists(db: db, table: "ZHOME", column: "ZINSURANCEPOLICY")

    if hasOldLabelFK {
        // Read from: SELECT i.Z_PK, i.ZLABEL FROM ZINVENTORYITEM WHERE ZLABEL IS NOT NULL
        // Maps item Z_PK → label Z_PK
    } else {
        // Read from join table: SELECT * FROM Z_2LABELS (or similar)
        // Maps item Z_PK → label Z_PK
    }

    if hasOldInsuranceFK {
        // Read from: SELECT h.Z_PK, h.ZINSURANCEPOLICY FROM ZHOME WHERE ZINSURANCEPOLICY IS NOT NULL
    } else {
        // Read from join table: SELECT * FROM Z_1INSURANCEPOLICIES (or similar)
    }
}
```

This reuses the same column/table detection logic already proven in `RelationshipMigrationHelper`.

### 2.4 Migration Order

**Order matters** (foreign keys must reference existing rows):
1. `InventoryLabel` (no dependencies)
2. `InventoryLocation` (no dependencies initially; homeID set in step 4)
3. `InsurancePolicy` (no dependencies)
4. `Home` (references InsurancePolicy via join table)
5. `InventoryItem` (references Location, Home, Labels)
6. Join tables: `InventoryItemLabel`, `HomeInsurancePolicy`
7. Back-fill `InventoryLocation.homeID` (references Home)

**ID Mapping**:
```swift
// Map old Core Data Z_PK → new sqlite-data Int64 IDs
var labelIDMap: [Int64: Int64] = [:]    // old Z_PK → new id
var locationIDMap: [Int64: Int64] = [:]
var policyIDMap: [Int64: Int64] = [:]
var homeIDMap: [Int64: Int64] = [:]
var itemIDMap: [Int64: Int64] = [:]
```

### 2.5 UIColor Deserialization

`InventoryLabel.color` is stored as a BLOB via `UIColorValueTransformer`. During migration:

```swift
// Read BLOB from SQLite
let colorBlob = sqlite3_column_blob(stmt, colorColumnIndex)
let colorLength = sqlite3_column_bytes(stmt, colorColumnIndex)

// Deserialize via NSKeyedUnarchiver (same as UIColorValueTransformer)
let data = Data(bytes: colorBlob, count: Int(colorLength))
if let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
    // Convert to hex string for sqlite-data storage
    let hexString = color.toHexString()
}
```

### 2.6 Date Conversion

Core Data stores dates as `TimeInterval` since 2001-01-01 (NSDate reference date). Convert during migration:

```swift
let coreDataTimestamp = sqlite3_column_double(stmt, dateColumnIndex)
let date = Date(timeIntervalSinceReferenceDate: coreDataTimestamp)
// Store as ISO 8601 string or Unix timestamp in sqlite-data
```

### 2.7 Progress UI

Update migration UI in `DatabaseManager` (replaces `ModelContainerManager`):
- "Upgrading to new storage format..."
- Progress bar for each model type
- "Verifying data integrity..."
- Rollback on failure with user-friendly error message

### 2.8 Validation & Rollback

After migration, validate:
```swift
// Record counts must match
assert(newLabelCount == oldLabelCount)
assert(newItemCount == oldItemCount)
// ... etc

// Spot-check a sample of records
// Verify all FK references are valid
// Verify join table entries are correct
```

If validation fails:
1. Delete the new sqlite-data database
2. Keep the old SwiftData store untouched
3. Show error UI with "Contact support" option
4. On next launch, retry migration

On success:
1. Move old `.store`, `.store-shm`, `.store-wal` to backup directory
2. Mark migration complete in UserDefaults

### 2.9 Testing Strategy

Create test migrations with:
- Empty database
- Small dataset (10 items)
- Large dataset (1000+ items)
- v2.1.0 schema (old FK columns)
- Post-multi-home schema (join tables)
- Mixed: some items have labels, some don't
- Edge cases (nil UUIDs, empty strings, NULL columns)
- Legacy image data still in `@Attribute(.externalStorage)`
- Pre-ID-stabilization data (missing ZID columns)

**Effort**: 5-6 days
**Risks**:
- Migration bugs could lose user data (extensive testing critical)
- Two schema formats to handle (old FKs vs join tables)
- UIColor BLOB deserialization must be tested carefully
- Date format conversion edge cases

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

This addresses the MVVM goal — queries can now live in ViewModels:

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

**Effort**: 3-4 days (27 @Query files + logic extraction)
**Risks**:
- Complex predicates may need SQL knowledge
- Breaking change to view architecture

---

## Phase 4: CloudKit Family Sharing (5-7 days) -- MOST COMPLEX

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

sqlite-data has full CKShare support for collaborative sharing ([source](https://www.pointfree.co/blog/posts/184-sqlitedata-1-0-an-alternative-to-swiftdata-with-cloudkit-sync-and-sharing)):

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

### 5.2 Replace ModelContainerManager

Replace `ModelContainerManager` with `DatabaseManager`:
```swift
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    let database: DatabaseQueue

    init() {
        // Run migration if needed
        SQLiteMigrationCoordinator.migrateIfNeeded(to: database)
        self.database = try! DatabaseQueue(/* config */)
    }
}
```

### 5.3 Remove RelationshipMigrationHelper

The `RelationshipMigrationHelper` raw SQLite patterns are absorbed into `SQLiteMigrationCoordinator`. The helper itself and its UserDefaults flags can be removed.

**Effort**: 2-3 days
**Risks**: Many files touch modelContext (27 files)

---

## Phase 6: Test Suite Refactoring (3-4 days)

### 6.1 Update Test Utilities

**Before**:
```swift
let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
- HomeDetailSettingsViewModelTests.swift
- 20+ other test files

### 6.3 Migration-Specific Tests

Add dedicated migration tests:
- Test migration from v2.1.0 schema (old FK columns)
- Test migration from post-multi-home schema (join tables)
- Test migration with empty database
- Test migration with missing columns (pre-ID-stabilization)
- Test rollback on validation failure
- Test re-migration after interrupted first attempt

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

## Phase 8: Cleanup & Removal (1-2 days)

Remove all SwiftData-specific code:
- `ModelContainerManager.swift`
- `RelationshipMigrationHelper.swift`
- `UIColorValueTransformer.swift` (if color is now stored as hex)
- All `@Model` class definitions (replaced by `@Table` structs)
- SwiftData import statements across all files
- `cloudKitDatabase: .none` workarounds in tests
- Migration-related UserDefaults keys (multi-home, ID stabilization, etc.)

**Effort**: 1-2 days

---

## Critical Issues & Risks

### High Risk

1. **Two Schema Formats in Production**
   - Users on v2.1.0 have old FK columns (ZLABEL, ZINSURANCEPOLICY)
   - Users who got the multi-home-cleanup release have join tables
   - Migration must detect and handle both formats correctly
   - Test with real databases from both versions

2. **CloudKit Family Sharing Complexity**
   - This is the most complex part by far
   - Requires extensive testing with multiple Apple IDs
   - See [Point-Free Episode #343](https://www.pointfree.co/episodes/ep343-cloudkit-sync-sharing) for implementation details

3. **Data Fidelity During Raw SQLite Read**
   - Must correctly deserialize UIColor BLOBs, NSDecimalNumber, Date timestamps
   - Core Data's internal column naming must be mapped accurately
   - NULL handling for optional properties
   - Pre-ID-stabilization rows may have NULL ZID columns

### Medium Risk

4. **UIColor → Hex Conversion**
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
   - SwiftData: `item.location?.name` (lazy loaded)
   - sqlite-data: Need join or separate fetch
   - May impact performance if not optimized

7. **PersistentIdentifier → Int64 ID Mapping**
   - SwiftData uses `PersistentIdentifier`, sqlite-data uses `Int64`
   - Any code storing/comparing IDs needs updating
   - Selection state in `InventoryListView` uses `Set<PersistentIdentifier>`

### Low Risk

8. **Image Storage**
   - Already using external `OptimizedImageManager`
   - URLs just need to be preserved during migration

9. **Library Maturity**
   - sqlite-data is relatively new (1.0 released recently)
   - Point-Free has good track record
   - Small user base reduces production risk

---

## Migration Testing Strategy

### Pre-Release Testing

1. **Unit Tests**: All models, migrations, queries
2. **Integration Tests**: Full migration with both schema versions
3. **UI Tests**: Sharing flows, conflict scenarios
4. **Beta Testing**: 2-3 willing users (export backup first!)
5. **Staging Environment**: Test with TestFlight before prod

### Migration Validation Suite

Automated checks that run after every migration:
- Record counts match (old store count == new database count) per model
- All FK references resolve to valid rows
- All join table entries reference valid rows on both sides
- UIColor hex values produce visually identical colors
- Date values are within 1 second of originals
- Image URLs are valid and files exist on disk
- No orphaned records in any table

### Test Databases

Prepare test fixtures:
- `test_v2.1.0.store` — database from production v2.1.0
- `test_post_multi_home.store` — database after multi-home migration
- `test_empty.store` — empty database (fresh install that was opened once)
- `test_large.store` — 1000+ items with all relationship types

---

## Recommended Implementation Order

### Phase A: Core Migration (stepping stones)
1. Convert `InventoryLabel` to `@Table` (simplest model, validates approach)
2. Build `SQLiteMigrationCoordinator` for that one model
3. Prove round-trip: old SQLite → sqlite-data → verify data matches

### Phase B: Full Migration
4. Convert remaining 4 models
5. Implement relationship migration (both schema formats)
6. Build validation suite
7. Test with real production-like databases

### Phase C: Query & Architecture
8. Replace `@Query` with `@FetchAll` across 27 files
9. Replace `modelContext` operations across 27 files
10. Extract query logic to ViewModels where appropriate

### Phase D: CloudKit & Sharing
11. Enable basic CloudKit sync (private database)
12. Test multi-device sync for single user
13. Implement CKShare support
14. Build sharing UI

### Phase E: Testing & Polish
15. Beta testing with real users
16. Bug fixes
17. Remove all SwiftData code
18. Final validation

---

## Alternatives Considered

1. **Staged releases (SwiftData relationship migration first, sqlite-data later)**
   - Pro: Smaller changes per release
   - Con: Users who skip versions need two migrations; more total code; version-skipping risk
   - **Rejected**: Single release is simpler end-to-end

2. **SwiftData VersionedSchema for intermediate migration**
   - Pro: "Official" SwiftData approach
   - Con: Requires maintaining exact V1 schema definition; same `loadIssueModelContainer` CloudKit issues; throwaway work if migrating to sqlite-data anyway
   - **Rejected**: Raw SQLite is more robust and directly feeds the sqlite-data migration

3. **Stay with SwiftData + NSPersistentCloudKitContainer**
   - Pro: Less work
   - Con: Family sharing still not possible, MVVM issues remain

4. **Core Data + CloudKit**
   - Pro: More mature, better documented
   - Con: More boilerplate, legacy API, similar MVVM issues

**Verdict**: Direct SwiftData SQLite → sqlite-data migration in a single release.

---

## Timeline Summary

| Phase | Effort | Priority |
|-------|--------|----------|
| 1. Schema Conversion | 3-4 days | High |
| 2. Data Migration (raw SQLite) | 5-6 days | Critical |
| 3. Query Refactoring | 3-4 days | High |
| 4. CloudKit Sharing | 5-7 days | Critical |
| 5. DI Refactoring | 2-3 days | Medium |
| 6. Test Suite | 3-4 days | High |
| 7. UI Polish | 2-3 days | Medium |
| 8. Cleanup & Removal | 1-2 days | Medium |
| **Total** | **24-33 days** | - |

---

## Resources

**sqlite-data Documentation & Articles**:
- [SQLiteData 1.0: CloudKit sync and sharing](https://www.pointfree.co/blog/posts/184-sqlitedata-1-0-an-alternative-to-swiftdata-with-cloudkit-sync-and-sharing)
- [SQLiteData Documentation - CloudKit Sharing](https://swiftpackageindex.com/pointfreeco/sqlite-data/1.3.0/documentation/sqlitedata/cloudkitsharing)
- [Point-Free Episode #343: CloudKit Sync - Sharing](https://www.pointfree.co/episodes/ep343-cloudkit-sync-sharing)
- [GitHub Repository](https://github.com/pointfreeco/sqlite-data)

**Apple CloudKit Resources**:
- [Get the most out of CloudKit Sharing - Tech Talks](https://developer.apple.com/videos/play/tech-talks/10874/)

**Existing Code to Reuse**:
- `RelationshipMigrationHelper.swift` — raw SQLite reading patterns, column/table detection, FK capture
- `ModelContainerManager.swift` — migration progress UI, UserDefaults gating, rollback patterns

---

## Decision Log

**Date**: 2026-01-06
**Decision**: Migrate from SwiftData to sqlite-data
**Rationale**:
- Enable collaborative family sharing (primary goal)
- Improve MVVM architecture by allowing queries in ViewModels
- Small user base reduces migration risk
- Automatic migration on first launch provides seamless UX

**Date**: 2026-02-01
**Decision**: Single-release migration using raw SQLite bridge (no intermediate SwiftData schema migration)
**Rationale**:
- Eliminates version-skipping risk (users on any prior version get clean migration)
- Avoids throwaway VersionedSchema work that would be removed with SwiftData
- Raw SQLite approach already proven in `RelationshipMigrationHelper`
- Handles both v2.1.0 (old FK columns) and post-multi-home (join tables) schemas
- Less total code than staged approach
**Constraints**:
- Must preserve all existing user data
- No manual export/import process
- Release when ready (no hard deadline)
