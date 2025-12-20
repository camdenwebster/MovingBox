# Technical Architecture: Multi-Home Support

**Document Version:** 1.0
**Created:** 2025-12-20
**Author:** iOS Architect Subagent
**Status:** Ready for Implementation

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Current Architecture Analysis](#2-current-architecture-analysis)
3. [Proposed Architecture](#3-proposed-architecture)
4. [Data Flow](#4-data-flow)
5. [Migration Strategy](#5-migration-strategy)
6. [Key Design Decisions](#6-key-design-decisions)
7. [Implementation Task List](#7-implementation-task-list)
8. [Testing Strategy](#8-testing-strategy)
9. [Risk Assessment](#9-risk-assessment)
10. [Scaling Considerations](#10-scaling-considerations)

---

## 1. Problem Statement

MovingBox currently treats `Home` as a de facto singleton. While the model exists, all `InventoryLocation` and `InventoryLabel` entities are global - they have no relationship to a specific home. This means:

- Users cannot maintain separate inventories for multiple properties
- Labels and locations are shared across all conceptual "homes"
- There is no way to switch context between different properties
- The navigation assumes a single home context

**Goal:** Transform MovingBox to support multiple homes with dedicated labels, locations, and items per home, while maintaining backward compatibility and a seamless upgrade experience for existing users.

---

## 2. Current Architecture Analysis

### 2.1 Data Models

**Current Relationships:**
```
Home (exists but singleton-like)
  - insurancePolicy: InsurancePolicy?

InventoryLocation (global, no home relationship)
  - inventoryItems: [InventoryItem]?

InventoryLabel (global, no home relationship)
  - inventoryItems: [InventoryItem]?

InventoryItem
  - location: InventoryLocation?
  - label: InventoryLabel?
```

**Key Files:**
| File | Current State | Impact |
|------|---------------|--------|
| `/MovingBox/Models/HomeModel.swift` | No isPrimary flag, no relationships to labels/locations | Major changes |
| `/MovingBox/Models/InventoryLocationModel.swift` | No home relationship | Add optional home reference |
| `/MovingBox/Models/InventoryLabelModel.swift` | No home relationship | Add optional home reference |
| `/MovingBox/Models/InventoryItemModel.swift` | Relates to home via location | Minimal direct changes |

### 2.2 Navigation Architecture

**Current Router (`/MovingBox/Services/Router.swift`):**
```swift
enum SidebarDestination: Hashable {
    case dashboard
    case allInventory
    case label(PersistentIdentifier)
    case location(PersistentIdentifier)
}
```

**Current SidebarView:**
- Uses `@Query` to fetch ALL labels and locations globally
- No concept of active home filtering
- Dashboard is hardcoded, not home-specific

### 2.3 Settings Architecture

**Current Structure (`/MovingBox/Views/Settings/SettingsView.swift`):**
```
Settings
  - Home Settings
    - Home Details (single home)
    - Location Settings (global)
    - Label Settings (global)
```

**SettingsManager (`/MovingBox/Services/SettingsManager.swift`):**
- No `activeHomeId` property
- No home selection persistence

### 2.4 Data Population

**DefaultDataManager (`/MovingBox/Services/DefaultDataManager.swift`):**
- `getOrCreateHome()` returns single home (uses `homes.last`)
- Labels and locations created globally, not per-home
- No support for home-scoped default data

---

## 3. Proposed Architecture

### 3.1 Updated Data Model

```
Home
  - name: String
  - address fields (existing)
  - isPrimary: Bool = false          [NEW]
  - locations: [InventoryLocation]   [NEW - inverse relationship]
  - labels: [InventoryLabel]         [NEW - inverse relationship]
  - insurancePolicy: InsurancePolicy?

InventoryLocation
  - name, desc, sfSymbolName (existing)
  - inventoryItems: [InventoryItem]?
  - home: Home?                      [NEW - parent relationship]

InventoryLabel
  - name, desc, color, emoji (existing)
  - inventoryItems: [InventoryItem]?
  - home: Home?                      [NEW - parent relationship]

InventoryItem (unchanged structure)
  - location: InventoryLocation?
  - label: InventoryLabel?
  - (relates to Home through location)
```

### 3.2 Updated Navigation Architecture

**Enhanced Router:**
```swift
enum SidebarDestination: Hashable {
    case dashboard                           // Primary home dashboard
    case home(PersistentIdentifier)          // NEW: Secondary home
    case allInventory                        // Aggregated across all homes
    case label(PersistentIdentifier)
    case location(PersistentIdentifier)
}

// Add to Router class:
@Published var activeHomeId: PersistentIdentifier?
```

**New Sidebar Structure:**
```
Sidebar
  - Dashboard (Primary Home)
  - Homes Section (NEW)
    - [Secondary homes listed here]
  - All Inventory
  - Locations Section (filtered by active home)
  - Labels Section (filtered by active home)
```

### 3.3 State Management

**SettingsManager Additions:**
```swift
// New UserDefaults keys
private enum Keys {
    // ... existing keys
    static let activeHomeId = "activeHomeId"
}

@Published var activeHomeId: String? {
    didSet {
        UserDefaults.standard.set(activeHomeId, forKey: Keys.activeHomeId)
    }
}
```

### 3.4 Settings Restructure

```
Settings
  - Home Settings
    - [Home List]
      - My House (Primary)
        - Home Details
        - Location Settings
        - Label Settings
        - Set as Primary
      - Beach House
        - Home Details
        - Location Settings
        - Label Settings
        - Set as Primary
        - Delete Home
    - Add Home (+)
```

---

## 4. Data Flow

### 4.1 Home Selection Flow

```
User taps home in sidebar
    |
    v
Router.activeHomeId updated
    |
    v
SettingsManager persists to UserDefaults
    |
    v
SidebarView re-queries with home filter
    |
    v
DashboardView updates to show selected home
```

### 4.2 Item Creation Flow (Multi-Home)

```
User creates new item
    |
    v
Check activeHomeId from SettingsManager
    |
    v
Filter available locations/labels by active home
    |
    v
Item.location set (links item to home indirectly)
    |
    v
CloudKit syncs item with relationships
```

### 4.3 All Inventory Flow

```
User selects "All Inventory"
    |
    v
Query all InventoryItems (no home filter)
    |
    v
Display with home badge for each item
    |
    v
Item detail shows home context
```

---

## 5. Migration Strategy

### 5.1 Schema Migration (SwiftData Automatic)

SwiftData handles schema evolution automatically for additive changes:
- New optional properties with defaults
- New optional relationships

**Changes are additive only:**
- `Home.isPrimary: Bool = false` (new property with default)
- `InventoryLocation.home: Home?` (new optional relationship)
- `InventoryLabel.home: Home?` (new optional relationship)

### 5.2 Data Migration (App-Level)

**Location in codebase:** `/MovingBox/Services/ModelContainerManager.swift`

```swift
// Add to ModelContainerManager
private let multiHomeMigrationKey = "MovingBox_MultiHomeMigration_v1"

private var isMultiHomeMigrationCompleted: Bool {
    UserDefaults.standard.bool(forKey: multiHomeMigrationKey)
}

func performMultiHomeMigration() async throws {
    guard !isMultiHomeMigrationCompleted else { return }

    let context = container.mainContext

    // 1. Get or create primary home
    let homeDescriptor = FetchDescriptor<Home>()
    let homes = try context.fetch(homeDescriptor)

    let primaryHome: Home
    if let existingHome = homes.first {
        primaryHome = existingHome
    } else {
        primaryHome = Home(name: "My Home")
        context.insert(primaryHome)
    }
    primaryHome.isPrimary = true

    // 2. Assign all orphaned locations to primary home
    let locationDescriptor = FetchDescriptor<InventoryLocation>()
    let locations = try context.fetch(locationDescriptor)
    for location in locations where location.home == nil {
        location.home = primaryHome
    }

    // 3. Assign all orphaned labels to primary home
    let labelDescriptor = FetchDescriptor<InventoryLabel>()
    let labels = try context.fetch(labelDescriptor)
    for label in labels where label.home == nil {
        label.home = primaryHome
    }

    // 4. Save and mark complete
    try context.save()
    UserDefaults.standard.set(true, forKey: multiHomeMigrationKey)

    // 5. Store active home ID
    let activeHomeId = primaryHome.persistentModelID.storeIdentifier
    UserDefaults.standard.set(activeHomeId, forKey: "activeHomeId")
}
```

### 5.3 Migration Timing

Migration runs during app initialization:
1. After SwiftData container creation
2. Before CloudKit sync is enabled
3. On first launch after update only (migration flag check)

---

## 6. Key Design Decisions

### 6.1 Home Relationship Strategy

**Decision:** Add optional `home: Home?` relationship to Location and Label models.

**Rationale:**
- Maintains backward compatibility (nil = legacy data)
- SwiftData handles optional relationships well
- Minimal impact on existing queries
- Clean migration path

**Alternatives Considered:**
- Required relationship: Would break existing data, complex migration
- Separate models per home: Massive code duplication, poor maintainability

### 6.2 Item-to-Home Relationship

**Decision:** Items relate to homes indirectly through their location.

**Rationale:**
- No direct changes to InventoryItem model
- Follows existing pattern (items already have location)
- Reduces model complexity
- Natural conceptual fit (items are "in" locations which are "in" homes)

**Edge Case - Unassigned Items:**
Items with `location == nil` still need home association. Options:
1. Add direct `home: Home?` to InventoryItem (more explicit)
2. Use label's home as fallback (assumes label is always set)
3. Allow truly orphaned items (simplest, may confuse users)

**Recommendation:** Option 1 - Add optional `home: Home?` to InventoryItem for explicit assignment when location is nil. This provides a clear fallback path.

### 6.3 Primary Home vs Active Home

**Decision:** Separate concepts:
- `isPrimary` (synced via CloudKit): Default home, appears as "Dashboard"
- `activeHomeId` (local UserDefaults): Currently selected home for this device

**Rationale:**
- Primary is a data property (which home is the "main" one)
- Active is a UI preference (what the user is viewing now)
- Different devices may want different active homes
- Primary designation syncs to maintain consistency

### 6.4 Label/Location Scope

**Decision:** Labels and Locations are per-home (not global).

**Rationale:**
- Matches user mental model (different homes have different rooms)
- Cleaner separation of concerns
- Simpler filtering logic
- Explicit in PRD requirements

### 6.5 Query Strategy

**Decision:** Use dynamic filtering rather than dynamic @Query predicates.

**Rationale:**
- SwiftUI @Query macro doesn't support dynamic predicates cleanly
- Filtering in-memory is performant for typical home sizes (< 100 locations)
- Simpler implementation
- Can optimize later if needed

**Implementation:**
```swift
// In SidebarView
@Query(sort: \InventoryLocation.name) private var allLocations: [InventoryLocation]

private var filteredLocations: [InventoryLocation] {
    guard let activeHomeId = settingsManager.activeHomeId else {
        return allLocations.filter { $0.home?.isPrimary == true }
    }
    return allLocations.filter {
        $0.home?.persistentModelID.storeIdentifier == activeHomeId
    }
}
```

---

## 7. Implementation Task List

### Phase 1: Data Model & Migration Foundation
**Estimated Duration: 3-4 days**

#### Task 1.1: Add isPrimary to Home Model
**File:** `/MovingBox/Models/HomeModel.swift`
**Estimate:** 1 hour
**Dependencies:** None

**Changes:**
```swift
@Model
class Home: PhotoManageable {
    // ... existing properties
    var isPrimary: Bool = false  // NEW
```

**Tests Required:**
- Unit test: Home creation with isPrimary default value
- Unit test: Setting isPrimary flag persists correctly

---

#### Task 1.2: Add home Relationship to InventoryLocation
**File:** `/MovingBox/Models/InventoryLocationModel.swift`
**Estimate:** 1 hour
**Dependencies:** Task 1.1

**Changes:**
```swift
@Model
class InventoryLocation: PhotoManageable {
    // ... existing properties
    var home: Home?  // NEW - parent relationship
```

**Tests Required:**
- Unit test: Location creation with nil home (backward compatible)
- Unit test: Location creation with home assignment
- Unit test: Inverse relationship (home.locations contains location)

---

#### Task 1.3: Add home Relationship to InventoryLabel
**File:** `/MovingBox/Models/InventoryLabelModel.swift`
**Estimate:** 1 hour
**Dependencies:** Task 1.1

**Changes:**
```swift
@Model
class InventoryLabel {
    // ... existing properties
    var home: Home?  // NEW - parent relationship
```

**Tests Required:**
- Unit test: Label creation with nil home (backward compatible)
- Unit test: Label creation with home assignment
- Unit test: Inverse relationship (home.labels contains label)

---

#### Task 1.4: Add home Relationship to InventoryItem (for unassigned items)
**File:** `/MovingBox/Models/InventoryItemModel.swift`
**Estimate:** 1 hour
**Dependencies:** Task 1.1

**Changes:**
```swift
@Model
final class InventoryItem: ObservableObject, PhotoManageable {
    // ... existing properties
    var home: Home?  // NEW - direct home relationship for items without location
```

**Computed property for effective home:**
```swift
var effectiveHome: Home? {
    location?.home ?? home
}
```

**Tests Required:**
- Unit test: Item with location inherits home from location
- Unit test: Item without location uses direct home reference
- Unit test: effectiveHome computed property

---

#### Task 1.5: Add activeHomeId to SettingsManager
**File:** `/MovingBox/Services/SettingsManager.swift`
**Estimate:** 1.5 hours
**Dependencies:** None

**Changes:**
```swift
private enum Keys {
    // ... existing keys
    static let activeHomeId = "activeHomeId"
}

@Published var activeHomeId: String? {
    didSet {
        if let id = activeHomeId {
            UserDefaults.standard.set(id, forKey: Keys.activeHomeId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.activeHomeId)
        }
    }
}

// Add to init:
self.activeHomeId = UserDefaults.standard.string(forKey: Keys.activeHomeId)
```

**Tests Required:**
- Unit test: activeHomeId persists to UserDefaults
- Unit test: activeHomeId restores on init
- Unit test: nil activeHomeId removes from UserDefaults

---

#### Task 1.6: Implement Multi-Home Migration
**File:** `/MovingBox/Services/ModelContainerManager.swift`
**Estimate:** 3 hours
**Dependencies:** Tasks 1.1-1.4

**Changes:**
- Add `performMultiHomeMigration()` method (see Section 5.2)
- Call during `initialize()` after existing migrations
- Add migration progress UI updates

**Tests Required:**
- Unit test: Migration assigns existing locations to primary home
- Unit test: Migration assigns existing labels to primary home
- Unit test: Migration creates primary home if none exists
- Unit test: Migration runs only once (flag check)
- Unit test: Migration handles empty database correctly

---

#### Task 1.7: Update DefaultDataManager for Home-Scoped Data
**File:** `/MovingBox/Services/DefaultDataManager.swift`
**Estimate:** 2 hours
**Dependencies:** Tasks 1.1-1.4

**Changes:**
```swift
static func populateDefaultLabels(modelContext: ModelContext, home: Home) async {
    // Create labels associated with specific home
}

static func populateDefaultLocations(modelContext: ModelContext, home: Home) async {
    // Create locations associated with specific home
}

static func createNewHome(name: String, modelContext: ModelContext) async throws -> Home {
    let home = Home(name: name)
    modelContext.insert(home)
    await populateDefaultLabels(modelContext: modelContext, home: home)
    await populateDefaultLocations(modelContext: modelContext, home: home)
    try modelContext.save()
    return home
}
```

**Tests Required:**
- Unit test: New home gets default labels
- Unit test: New home gets default locations
- Unit test: Labels/locations properly linked to home

---

### Phase 2: Navigation & Home Switching
**Estimated Duration: 3-4 days**

#### Task 2.1: Update Router with Home Selection State
**File:** `/MovingBox/Services/Router.swift`
**Estimate:** 1.5 hours
**Dependencies:** Phase 1

**Changes:**
```swift
enum SidebarDestination: Hashable, Identifiable {
    case dashboard
    case home(PersistentIdentifier)  // NEW
    case allInventory
    case label(PersistentIdentifier)
    case location(PersistentIdentifier)

    var id: String {
        switch self {
        // ... existing cases
        case .home(let id):
            return "home-\(id.hashValue)"
        }
    }
}
```

**Tests Required:**
- Unit test: SidebarDestination.home equality
- Unit test: SidebarDestination.home hashability

---

#### Task 2.2: Restructure SidebarView with Homes Section
**File:** `/MovingBox/Views/Navigation/SidebarView.swift`
**Estimate:** 3 hours
**Dependencies:** Task 2.1

**Changes:**
```swift
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager
    @Query(sort: \InventoryLabel.name) private var allLabels: [InventoryLabel]
    @Query(sort: \InventoryLocation.name) private var allLocations: [InventoryLocation]
    @Query(sort: \Home.name) private var homes: [Home]
    @Binding var selection: Router.SidebarDestination?

    private var primaryHome: Home? {
        homes.first { $0.isPrimary }
    }

    private var secondaryHomes: [Home] {
        homes.filter { !$0.isPrimary }
    }

    private var activeHome: Home? {
        guard let activeId = settingsManager.activeHomeId else {
            return primaryHome
        }
        return homes.first { $0.persistentModelID.storeIdentifier == activeId }
    }

    private var filteredLocations: [InventoryLocation] {
        allLocations.filter { $0.home?.persistentModelID == activeHome?.persistentModelID }
    }

    private var filteredLabels: [InventoryLabel] {
        allLabels.filter { $0.home?.persistentModelID == activeHome?.persistentModelID }
    }

    var body: some View {
        List(selection: $selection) {
            // Dashboard (Primary Home)
            NavigationLink(value: Router.SidebarDestination.dashboard) {
                Label("Dashboard", systemImage: "house.fill")
            }

            // Homes Section (only show if multiple homes)
            if !secondaryHomes.isEmpty {
                Section("Homes") {
                    ForEach(secondaryHomes, id: \.persistentModelID) { home in
                        NavigationLink(value: Router.SidebarDestination.home(home.persistentModelID)) {
                            Label(home.name.isEmpty ? "Unnamed Home" : home.name,
                                  systemImage: "building.2")
                        }
                    }
                }
            }

            // All Inventory
            NavigationLink(value: Router.SidebarDestination.allInventory) {
                Label("All Inventory", systemImage: "shippingbox.fill")
            }

            // Locations (filtered by active home)
            Section("Locations") {
                // ... filtered locations
            }

            // Labels (filtered by active home)
            Section("Labels") {
                // ... filtered labels
            }
        }
    }
}
```

**Tests Required:**
- Unit test: Primary home appears as Dashboard
- Unit test: Secondary homes appear in Homes section
- Unit test: Locations filter by active home
- Unit test: Labels filter by active home
- Snapshot test: Sidebar with single home
- Snapshot test: Sidebar with multiple homes

---

#### Task 2.3: Update MainSplitView for Home Destinations
**File:** `/MovingBox/Views/Navigation/MainSplitView.swift`
**Estimate:** 2 hours
**Dependencies:** Tasks 2.1, 2.2

**Changes:**
```swift
@ViewBuilder
private func detailView(for sidebarDestination: Router.SidebarDestination?) -> some View {
    switch sidebarDestination {
    case .dashboard:
        DashboardView()
    case .home(let homeId):
        if let home = modelContext.model(for: homeId) as? Home {
            DashboardView(home: home)  // Pass specific home
        } else {
            ContentUnavailableView("Home Not Found", systemImage: "house.slash")
        }
    case .allInventory:
        InventoryListView(location: nil, showAllHomes: true)
    // ... other cases
    }
}
```

**Tests Required:**
- Unit test: Dashboard destination shows primary home
- Unit test: Home destination shows specific home
- Unit test: All Inventory shows all homes indicator

---

#### Task 2.4: Update DashboardView for Specific Home
**File:** `/MovingBox/Views/Home Views/DashboardView.swift`
**Estimate:** 2.5 hours
**Dependencies:** Task 2.3

**Changes:**
- Add optional `home: Home?` parameter
- Filter items, locations, labels by home when provided
- Update title to show home name
- Add home selection state update on appear

```swift
struct DashboardView: View {
    let home: Home?  // nil = primary home

    init(home: Home? = nil) {
        self.home = home
    }

    private var displayHome: Home? {
        home ?? homes.first { $0.isPrimary }
    }

    private var homeItems: [InventoryItem] {
        items.filter { $0.effectiveHome?.persistentModelID == displayHome?.persistentModelID }
    }

    // Update all item queries to use homeItems
}
```

**Tests Required:**
- Unit test: DashboardView shows primary home by default
- Unit test: DashboardView shows specified home
- Unit test: Item counts filter by home
- Snapshot test: Dashboard for specific home

---

#### Task 2.5: Implement Active Home Selection Logic
**File:** `/MovingBox/Views/Navigation/SidebarView.swift`
**Estimate:** 1.5 hours
**Dependencies:** Tasks 2.2, 2.4

**Changes:**
```swift
// Add home selection handling
.onChange(of: selection) { _, newValue in
    switch newValue {
    case .dashboard:
        settingsManager.activeHomeId = primaryHome?.persistentModelID.storeIdentifier
    case .home(let homeId):
        if let home = modelContext.model(for: homeId) as? Home {
            settingsManager.activeHomeId = home.persistentModelID.storeIdentifier
        }
    default:
        break
    }
}
```

**Tests Required:**
- Unit test: Selecting dashboard updates activeHomeId to primary
- Unit test: Selecting home updates activeHomeId
- Unit test: activeHomeId persists across app restart

---

#### Task 2.6: Add Home Badge to All Inventory Items
**File:** `/MovingBox/Views/Items/InventoryListView.swift`
**Estimate:** 2 hours
**Dependencies:** Task 2.3

**Changes:**
- Add `showAllHomes: Bool` parameter
- When true, show home badge on each item
- Update row to display home name

```swift
// In item row when showAllHomes is true
if showAllHomes, let homeName = item.effectiveHome?.name {
    Text(homeName)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
}
```

**Tests Required:**
- Unit test: All Inventory shows home badges
- Unit test: Single home view hides home badges
- Snapshot test: All Inventory list with badges

---

### Phase 3: Home Management in Settings
**Estimated Duration: 3-4 days**

#### Task 3.1: Create HomeListView for Settings
**File:** `/MovingBox/Views/Settings/HomeListView.swift` (NEW)
**Estimate:** 2.5 hours
**Dependencies:** Phase 2

```swift
struct HomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var router: Router
    @Query(sort: \Home.name) private var homes: [Home]

    var body: some View {
        List {
            ForEach(homes, id: \.persistentModelID) { home in
                NavigationLink {
                    HomeDetailSettingsView(home: home)
                } label: {
                    HStack {
                        Text(home.name.isEmpty ? "Unnamed Home" : home.name)
                        Spacer()
                        if home.isPrimary {
                            Text("Primary")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteHomes)

            Button {
                addNewHome()
            } label: {
                Label("Add Home", systemImage: "plus")
            }
        }
        .navigationTitle("Home Settings")
    }

    private func deleteHomes(at offsets: IndexSet) {
        // Prevent deleting last home or primary home
    }

    private func addNewHome() {
        // Navigate to add home flow
    }
}
```

**Tests Required:**
- Unit test: All homes appear in list
- Unit test: Primary home shows indicator
- Unit test: Cannot delete last home
- Snapshot test: Home list view

---

#### Task 3.2: Create HomeDetailSettingsView
**File:** `/MovingBox/Views/Settings/HomeDetailSettingsView.swift` (NEW)
**Estimate:** 3 hours
**Dependencies:** Task 3.1

```swift
struct HomeDetailSettingsView: View {
    @Bindable var home: Home
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Home Details") {
                // Existing EditHomeView content
            }

            Section("Organization") {
                NavigationLink {
                    HomeLocationSettingsView(home: home)
                } label: {
                    Label("Locations", systemImage: "location")
                }

                NavigationLink {
                    HomeLabelSettingsView(home: home)
                } label: {
                    Label("Labels", systemImage: "tag")
                }
            }

            Section {
                if !home.isPrimary {
                    Button("Set as Primary Home") {
                        setPrimaryHome()
                    }
                }
            }

            if !home.isPrimary {
                Section {
                    Button("Delete Home", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(home.name.isEmpty ? "Home Details" : home.name)
    }
}
```

**Tests Required:**
- Unit test: Home details editable
- Unit test: Set as primary changes flag
- Unit test: Delete removes home and cascade
- Unit test: Cannot delete primary home
- Snapshot test: Home detail settings

---

#### Task 3.3: Create HomeLocationSettingsView
**File:** `/MovingBox/Views/Settings/HomeLocationSettingsView.swift` (NEW)
**Estimate:** 1.5 hours
**Dependencies:** Task 3.2

Refactor existing `LocationSettingsView` to accept home filter:

```swift
struct HomeLocationSettingsView: View {
    let home: Home
    @Query private var allLocations: [InventoryLocation]

    private var homeLocations: [InventoryLocation] {
        allLocations.filter { $0.home?.persistentModelID == home.persistentModelID }
            .sorted { $0.name < $1.name }
    }

    // ... rest of view similar to LocationSettingsView
}
```

**Tests Required:**
- Unit test: Only home's locations shown
- Unit test: New location gets home assignment
- Snapshot test: Location settings for home

---

#### Task 3.4: Create HomeLabelSettingsView
**File:** `/MovingBox/Views/Settings/HomeLabelSettingsView.swift` (NEW)
**Estimate:** 1.5 hours
**Dependencies:** Task 3.2

Similar to Task 3.3 for labels.

**Tests Required:**
- Unit test: Only home's labels shown
- Unit test: New label gets home assignment
- Snapshot test: Label settings for home

---

#### Task 3.5: Create AddHomeView
**File:** `/MovingBox/Views/Settings/AddHomeView.swift` (NEW)
**Estimate:** 2 hours
**Dependencies:** Tasks 3.1, 1.7

```swift
struct AddHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var homeName = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Home Name") {
                    TextField("Enter home name", text: $homeName)
                }

                Section {
                    Text("Default locations and labels will be created for this home.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Home")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createHome()
                    }
                    .disabled(homeName.isEmpty || isCreating)
                }
            }
        }
    }

    private func createHome() {
        isCreating = true
        Task {
            do {
                let _ = try await DefaultDataManager.createNewHome(
                    name: homeName,
                    modelContext: modelContext
                )
                dismiss()
            } catch {
                // Handle error
            }
            isCreating = false
        }
    }
}
```

**Tests Required:**
- Unit test: Home created with name
- Unit test: Default data populated
- Unit test: Cannot create with empty name
- Snapshot test: Add home view

---

#### Task 3.6: Update SettingsView Structure
**File:** `/MovingBox/Views/Settings/SettingsView.swift`
**Estimate:** 1.5 hours
**Dependencies:** Tasks 3.1-3.5

**Changes:**
Replace single home link with HomeListView navigation:

```swift
Section("Home Settings") {
    NavigationLink {
        HomeListView()
    } label: {
        Label("Manage Homes", systemImage: "house")
    }
}
```

Remove direct links to Location Settings and Label Settings (now under each home).

**Tests Required:**
- Unit test: Settings navigates to home list
- Snapshot test: Updated settings view

---

#### Task 3.7: Implement Home Deletion with Cascade
**File:** `/MovingBox/Views/Settings/HomeDetailSettingsView.swift`
**Estimate:** 2 hours
**Dependencies:** Task 3.2

**Changes:**
```swift
private func deleteHome() {
    // 1. Verify not primary and not last home
    guard !home.isPrimary else { return }

    // 2. Get all items associated with this home
    let items = home.locations?.flatMap { $0.inventoryItems ?? [] } ?? []

    // 3. Delete all items
    for item in items {
        modelContext.delete(item)
    }

    // 4. Delete all locations (cascade from home delete)
    // 5. Delete all labels (cascade from home delete)

    // 6. Delete home
    modelContext.delete(home)

    // 7. Update active home if this was active
    if settingsManager.activeHomeId == home.persistentModelID.storeIdentifier {
        settingsManager.activeHomeId = nil  // Will fall back to primary
    }

    try? modelContext.save()
}
```

**Tests Required:**
- Unit test: Deleting home deletes locations
- Unit test: Deleting home deletes labels
- Unit test: Deleting home deletes items
- Unit test: Active home updates on delete
- Unit test: Cannot delete primary home

---

### Phase 4: Polish & Edge Cases
**Estimated Duration: 2-3 days**

#### Task 4.1: Handle Orphaned Items (No Location)
**File:** Multiple files
**Estimate:** 1.5 hours
**Dependencies:** Phase 3

Ensure items without location still have home association:

- When creating item, set `item.home` if `item.location == nil`
- When clearing item location, preserve home reference
- Migration assigns home to orphaned items

**Tests Required:**
- Unit test: Item without location has home
- Unit test: Clearing location preserves home

---

#### Task 4.2: Add Telemetry Events
**File:** `/MovingBox/Services/TelemetryManager.swift`
**Estimate:** 1.5 hours
**Dependencies:** Phase 3

**New Events:**
- `home_created`
- `home_deleted`
- `home_selected`
- `home_primary_changed`
- `all_inventory_viewed`
- `multi_home_migration_complete`

**Tests Required:**
- Unit test: Events fire with correct properties

---

#### Task 4.3: Update Item Pickers for Active Home
**Files:** `/MovingBox/Views/Items/AddInventoryItemView.swift`, etc.
**Estimate:** 2 hours
**Dependencies:** Phase 2

Filter location and label pickers by active home:

```swift
private var availableLocations: [InventoryLocation] {
    allLocations.filter { $0.home?.persistentModelID == activeHome?.persistentModelID }
}

private var availableLabels: [InventoryLabel] {
    allLabels.filter { $0.home?.persistentModelID == activeHome?.persistentModelID }
}
```

**Tests Required:**
- Unit test: Pickers show only active home options
- UI test: Add item flow shows correct locations

---

#### Task 4.4: Update Export for Multi-Home
**File:** `/MovingBox/Services/DataManager.swift`
**Estimate:** 2 hours
**Dependencies:** Phase 1

Add home column to CSV export:

```swift
// Add to CSV header
"Home",

// Add to each row
item.effectiveHome?.name ?? "Unassigned",
```

**Tests Required:**
- Unit test: Export includes home column
- Unit test: Import handles home column (future)

---

#### Task 4.5: UI Polish and Accessibility
**Files:** Multiple views
**Estimate:** 2 hours
**Dependencies:** All phases

- Add accessibility identifiers for UI testing
- Ensure VoiceOver support for home selection
- Add loading states for home switching
- Polish animations for sidebar updates

**Tests Required:**
- Accessibility audit
- UI test: Home switching flow

---

### Code Review Checkpoints

**Checkpoint 1: After Phase 1 (Data Model)**
- Review model changes for CloudKit compatibility
- Verify migration logic correctness
- Confirm backward compatibility

**Checkpoint 2: After Phase 2 (Navigation)**
- Review Router architecture changes
- Verify state management patterns
- Confirm query performance

**Checkpoint 3: After Phase 3 (Settings)**
- Review delete cascade logic
- Verify home creation flow
- Confirm settings restructure UX

**Checkpoint 4: Final Review**
- Full code review
- Performance testing
- Security review

---

## 8. Testing Strategy

### 8.1 Unit Tests

**Model Tests:**
- Home relationship tests
- Migration logic tests
- SettingsManager persistence tests

**Service Tests:**
- DefaultDataManager home-scoped creation
- ModelContainerManager migration

### 8.2 Integration Tests

- Full migration flow with sample data
- Home switching with data filtering
- Delete cascade verification

### 8.3 UI Tests

**Critical Flows:**
- Create new home end-to-end
- Switch between homes
- Delete home with confirmation
- All Inventory aggregation

### 8.4 Snapshot Tests

**Views to Snapshot:**
- SidebarView (single home)
- SidebarView (multiple homes)
- DashboardView (specific home)
- HomeListView
- HomeDetailSettingsView

### 8.5 CloudKit Sync Tests

- Multi-device sync of home creation
- Primary home conflict resolution
- Delete propagation across devices

---

## 9. Risk Assessment

### 9.1 High Risk

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss during migration | Low | Critical | Test extensively; backup before migration; rollback capability |
| CloudKit sync conflicts | Medium | High | Use additive schema only; test multi-device; document conflict resolution |
| Performance with many homes | Low | Medium | Lazy loading; pagination; reasonable limit (10 homes) |

### 9.2 Medium Risk

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Complex query refactoring | High | Medium | Comprehensive test coverage; incremental rollout |
| User confusion | Medium | Medium | Clear UI; onboarding tips for multi-home |
| Settings complexity | Medium | Medium | Progressive disclosure; collapsible sections |

### 9.3 Low Risk

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Orphaned items | Low | Low | Direct home reference fallback |
| Performance regression | Low | Low | Profile before/after; optimize queries |

---

## 10. Scaling Considerations

### 10.1 Data Scaling

- **10 homes:** No performance concerns expected
- **100 homes:** May need pagination in sidebar
- **1000+ items per home:** Already handled by existing lazy loading

### 10.2 Future Enhancements (Out of Scope)

- **Home sharing:** Multi-user collaboration
- **Home templates:** Duplicate home structure
- **Bulk item transfer:** Move items between homes
- **Per-home export:** Export single home's data

### 10.3 Architecture Extensibility

The proposed architecture supports future enhancements:
- Home relationship is nullable (supports gradual feature adoption)
- Router pattern allows additional home-scoped destinations
- Settings structure can accommodate per-home preferences

---

## Summary

### Timeline

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1 | 3-4 days | Model changes, migration, SettingsManager |
| Phase 2 | 3-4 days | Sidebar, Router, Dashboard, home switching |
| Phase 3 | 3-4 days | Settings restructure, home CRUD |
| Phase 4 | 2-3 days | Polish, telemetry, edge cases |
| **Total** | **11-15 days** | Complete multi-home support |

### Key Success Criteria

1. Existing users see zero data loss after update
2. Home switching is instant (< 500ms)
3. CloudKit sync works without conflicts
4. All tests pass with 90%+ coverage
5. No breaking changes to existing workflows

---

**Document History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-20 | iOS Architect | Initial architecture document |
