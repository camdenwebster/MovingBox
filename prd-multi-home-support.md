# Product Requirements Document: Multi-Home Support

**Document Version:** 1.0
**Created:** 2025-12-20
**Last Updated:** 2025-12-20
**Author:** Product Manager Subagent
**Status:** Draft

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [User Value](#2-user-value)
3. [Success Metrics](#3-success-metrics)
4. [User Stories](#4-user-stories)
5. [Detailed Requirements](#5-detailed-requirements)
6. [Technical Considerations](#6-technical-considerations)
7. [Implementation Phases](#7-implementation-phases)
8. [Risks and Mitigations](#8-risks-and-mitigations)
9. [Non-Goals](#9-non-goals)
10. [Open Questions](#10-open-questions)

---

## 1. Problem Statement

### Current Situation

MovingBox currently supports only a single home per user. The `Home` model exists but functions as a singleton - there is exactly one home that contains all inventory items, labels, and locations. Users who own or manage multiple properties (vacation homes, rental properties, storage units, or who are helping family members) cannot effectively organize their inventory by property.

### Core Problem

Users with multiple properties cannot:
- Maintain separate inventories for each property
- Have property-specific labels and locations
- View consolidated inventory across all properties when needed
- Quickly switch context between different homes

### Impact

- Users managing multiple properties resort to workarounds (naming conventions, complex label systems)
- Potential users who need multi-property support choose competitor apps
- Insurance documentation becomes difficult when properties have different policies
- The app cannot serve property managers, landlords, or users with vacation homes

---

## 2. User Value

### Primary Value Propositions

| User Segment | Value Delivered |
|--------------|-----------------|
| **Homeowners with multiple properties** | Organize inventory separately per property while maintaining one app |
| **Vacation home owners** | Track furnishings and equipment at secondary residences |
| **Property managers** | Manage inventory across rental properties |
| **Users helping family** | Help elderly parents or family members catalog their homes separately |
| **Users with storage units** | Track items stored off-site separately from home inventory |

### User Benefits

1. **Organization**: Each home has dedicated inventory, labels, and locations
2. **Clarity**: No confusion about which items belong where
3. **Insurance**: Separate inventories for separate insurance policies
4. **Context Switching**: Easy navigation between homes
5. **Flexibility**: View all inventory together or by individual home

---

## 3. Success Metrics

### Primary KPIs

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| **Multi-home adoption rate** | 15% of active users create 2+ homes within 30 days of feature launch | Analytics: count of users with multiple homes |
| **Feature retention** | 80% of multi-home users continue using feature after 30 days | Analytics: retention cohort analysis |
| **User satisfaction** | 4.0+ rating for feature in feedback surveys | In-app survey or App Store reviews |

### Secondary KPIs

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| **Average homes per multi-home user** | 2.5 homes | Analytics: homes count per user |
| **Cross-home navigation frequency** | 3+ switches per session for multi-home users | Analytics: home selection events |
| **All Inventory usage** | 40% of multi-home users use "All Inventory" weekly | Analytics: sidebar navigation events |

### Quality Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| **Data migration success rate** | 100% of existing data migrated to primary home | Automated testing + manual QA |
| **CloudKit sync stability** | No increase in sync errors | Error tracking via Sentry |
| **Performance** | Home switching < 500ms | Performance monitoring |

---

## 4. User Stories

### Epic: Multi-Home Management

#### US-1: Create Additional Home
**As a** MovingBox user
**I want to** create a new home in the app
**So that** I can organize inventory for my second property separately

**Acceptance Criteria:**
- [ ] User can access "Add Home" option from Settings > Home Settings
- [ ] New home creation form includes: name (required), address fields (optional), photo (optional)
- [ ] New home is created with default labels and locations (same as first-launch experience)
- [ ] User is notified that the home was created successfully
- [ ] New home appears in the sidebar under "Homes" section
- [ ] Analytics event tracked for home creation

#### US-2: Navigate Between Homes (Sidebar)
**As a** user with multiple homes
**I want to** switch between homes using the sidebar
**So that** I can quickly access different property inventories

**Acceptance Criteria:**
- [ ] Sidebar displays "Dashboard" at top (shows currently active/primary home)
- [ ] "Homes" section lists all homes below Dashboard
- [ ] Selecting a home from the list makes it the active home
- [ ] Active home selection persists across app restarts (UserDefaults)
- [ ] When a home is selected, Dashboard updates to show that home's data
- [ ] Locations and Labels sections filter to show only selected home's data

#### US-3: View All Inventory
**As a** user with multiple homes
**I want to** see inventory from ALL my homes in one list
**So that** I can search across properties or get a complete overview

**Acceptance Criteria:**
- [ ] "All Inventory" option in sidebar shows items from all homes
- [ ] All Inventory list displays home name for each item (badge or subtitle)
- [ ] Filtering and sorting work across all homes
- [ ] Search spans all homes
- [ ] Item count reflects total across all properties

#### US-4: Delete Home
**As a** user
**I want to** delete a home I no longer need
**So that** I can keep my home list clean

**Acceptance Criteria:**
- [ ] User can delete a home from Settings > Home Settings
- [ ] Deletion requires confirmation with warning about data loss
- [ ] Cannot delete last remaining home (delete button disabled with explanation)
- [ ] Deleting a home also deletes all associated items, locations, and labels
- [ ] If active home is deleted, app switches to another home automatically
- [ ] Analytics event tracked for home deletion

#### US-5: Rename Home
**As a** user
**I want to** rename a home
**So that** I can update the name if I move or change usage

**Acceptance Criteria:**
- [ ] User can edit home name from Settings > Home Settings > [Select Home]
- [ ] Name change is reflected immediately in sidebar
- [ ] Name is synced via CloudKit to other devices

#### US-6: Migrate Existing Data to Primary Home
**As an** existing MovingBox user upgrading to multi-home version
**I want** my existing inventory, labels, and locations preserved
**So that** I don't lose any data during the upgrade

**Acceptance Criteria:**
- [ ] All existing InventoryItems are assigned to a default "Primary Home"
- [ ] All existing InventoryLocations are assigned to the Primary Home
- [ ] All existing InventoryLabels are assigned to the Primary Home
- [ ] Existing Home entity becomes the Primary Home (isPrimary = true)
- [ ] Migration is automatic and requires no user action
- [ ] Migration occurs during app update, before user interaction

#### US-7: Home-Specific Labels and Locations
**As a** user with multiple homes
**I want** each home to have its own labels and locations
**So that** I can customize organization per property

**Acceptance Criteria:**
- [ ] Labels are scoped to individual homes
- [ ] Locations are scoped to individual homes
- [ ] When viewing a home, only that home's labels/locations appear in pickers
- [ ] Settings > Labels and Settings > Locations moved inside each home's settings
- [ ] Default labels and locations created for each new home

#### US-8: Set Primary Home
**As a** user with multiple homes
**I want to** designate one home as my primary/default home
**So that** the app opens to that home by default

**Acceptance Criteria:**
- [ ] One home is always marked as primary (isPrimary flag)
- [ ] Primary home is shown at top of sidebar as "Dashboard"
- [ ] User can change which home is primary from Settings
- [ ] Primary designation persists via CloudKit

---

## 5. Detailed Requirements

### 5.1 Data Model Changes

#### Home Model Updates
```
Home (existing model - requires updates)
- name: String (existing)
- address1, address2, city, state, zip, country: String (existing)
- purchaseDate: Date (existing)
- purchasePrice: Decimal (existing)
- imageURL: URL? (existing)
- insurancePolicy: InsurancePolicy? (existing)
+ isPrimary: Bool = false (NEW - marks default home)
+ labels: [InventoryLabel] (NEW - inverse relationship)
+ locations: [InventoryLocation] (NEW - inverse relationship)
+ items: [InventoryItem] (NEW - inverse relationship, derived through locations)
```

#### InventoryLocation Model Updates
```
InventoryLocation (existing model - requires updates)
- name: String (existing)
- desc: String (existing)
- sfSymbolName: String? (existing)
- imageURL: URL? (existing)
- inventoryItems: [InventoryItem]? (existing)
+ home: Home? (NEW - parent relationship)
```

#### InventoryLabel Model Updates
```
InventoryLabel (existing model - requires updates)
- name: String (existing)
- desc: String (existing)
- color: UIColor? (existing)
- emoji: String (existing)
- inventoryItems: [InventoryItem]? (existing)
+ home: Home? (NEW - parent relationship)
```

#### InventoryItem Model (Indirect Changes)
- No direct changes needed
- Items relate to homes through their location
- Items can optionally have labels from their home

### 5.2 Navigation Changes

#### Sidebar Structure (New)
```
[Sidebar]
- Dashboard               <- Primary home (always at top)
- Homes
  - Beach House           <- Secondary homes listed here
  - Storage Unit
- All Inventory           <- Aggregated view (NEW position)
- [Locations Section]     <- Filtered by active home
  - Living Room
  - Kitchen
  - ...
- [Labels Section]        <- Filtered by active home
  - Electronics
  - Furniture
  - ...
```

#### Active Home State
- Stored in UserDefaults as `activeHomeId: String` (PersistentIdentifier)
- Read on app launch to restore selection
- Updated when user selects home from sidebar
- Falls back to primary home if stored ID is invalid

### 5.3 Settings Changes

#### Current Settings Structure
```
Settings
- Home Settings
  - Home Details
  - Location Settings
  - Label Settings
- ...
```

#### New Settings Structure
```
Settings
- Home Settings
  - [Home List]
    - My House (Primary)    <- Tap to expand
      - Home Details
      - Location Settings
      - Label Settings
      - Set as Primary
    - Beach House           <- Tap to expand
      - Home Details
      - Location Settings
      - Label Settings
      - Set as Primary
      - Delete Home
  - Add Home (+)
- ...
```

### 5.4 Data Persistence Requirements

#### UserDefaults Keys
- `activeHomeId: String` - Currently selected home's identifier
- `primaryHomeId: String` - Default home identifier (backup for isPrimary)

#### CloudKit Sync
- All model changes must be additive (no breaking changes)
- New relationships sync automatically via SwiftData CloudKit integration
- Migration flag stored locally to prevent re-migration

### 5.5 Business Rules

| Rule | Description |
|------|-------------|
| **BR-1** | At least one home must exist at all times |
| **BR-2** | Exactly one home must be marked as primary |
| **BR-3** | Deleting a home cascades to delete its locations, labels, and items |
| **BR-4** | Cannot delete the last remaining home |
| **BR-5** | New homes receive default labels and locations from TestData |
| **BR-6** | Primary home cannot be deleted directly (must transfer primary first) |
| **BR-7** | Items without a location are still associated with a home (via null location) |

---

## 6. Technical Considerations

### 6.1 Current Architecture Analysis

#### Relevant Files and Components

| Component | File Path | Impact |
|-----------|-----------|--------|
| Home Model | `/MovingBox/Models/HomeModel.swift` | Add isPrimary, relationships |
| Location Model | `/MovingBox/Models/InventoryLocationModel.swift` | Add home relationship |
| Label Model | `/MovingBox/Models/InventoryLabelModel.swift` | Add home relationship |
| Router | `/MovingBox/Services/Router.swift` | Add home selection state |
| Sidebar | `/MovingBox/Views/Navigation/SidebarView.swift` | Restructure for homes |
| MainSplitView | `/MovingBox/Views/Navigation/MainSplitView.swift` | Handle home context |
| DashboardView | `/MovingBox/Views/Home Views/DashboardView.swift` | Filter by active home |
| SettingsView | `/MovingBox/Views/Settings/SettingsView.swift` | Restructure home settings |
| DefaultDataManager | `/MovingBox/Services/DefaultDataManager.swift` | Home-aware data creation |
| SettingsManager | `/MovingBox/Services/SettingsManager.swift` | Store activeHomeId |
| ModelContainerManager | `/MovingBox/Services/ModelContainerManager.swift` | Migration logic |

### 6.2 Migration Strategy

#### Phase 1: Schema Migration (Automatic via SwiftData)
1. Add optional `home` relationship to `InventoryLocation`
2. Add optional `home` relationship to `InventoryLabel`
3. Add `isPrimary` flag to `Home`

#### Phase 2: Data Migration (App-Level)
```swift
func migrateToMultiHome(context: ModelContext) async {
    // 1. Get or create primary home
    let homes = try context.fetch(FetchDescriptor<Home>())
    let primaryHome = homes.first ?? Home(name: "My Home")
    primaryHome.isPrimary = true

    // 2. Assign all existing locations to primary home
    let locations = try context.fetch(FetchDescriptor<InventoryLocation>())
    for location in locations where location.home == nil {
        location.home = primaryHome
    }

    // 3. Assign all existing labels to primary home
    let labels = try context.fetch(FetchDescriptor<InventoryLabel>())
    for label in labels where label.home == nil {
        label.home = primaryHome
    }

    // 4. Save migration state
    UserDefaults.standard.set(true, forKey: "multiHomeMigrationComplete")
    try context.save()
}
```

### 6.3 CloudKit Considerations

#### Additive Changes Only
- New properties with default values (isPrimary = false)
- New optional relationships (home: Home?)
- No field removals or type changes

#### Sync Behavior
- Existing data syncs normally with new nil relationships
- Migration runs on each device independently
- Primary home designation syncs across devices

#### Conflict Resolution
- If multiple devices set different primary homes, last-write-wins
- Consider: should primary be device-local preference?

### 6.4 Performance Considerations

| Concern | Mitigation |
|---------|------------|
| Query filtering by home | Add compound indexes on (home, name) for locations/labels |
| All Inventory performance | Lazy loading, pagination for large inventories |
| Home switching speed | Pre-fetch active home's data |
| Migration time | Background migration with progress indicator |

### 6.5 SwiftData Query Updates

#### Current Queries (Examples)
```swift
// Current: Fetches ALL locations
@Query(sort: \InventoryLocation.name) private var locations: [InventoryLocation]

// Current: Fetches ALL items
@Query private var items: [InventoryItem]
```

#### Updated Queries
```swift
// New: Filter by active home (requires dynamic predicate)
// Option 1: Use @Query with dynamic predicate
// Option 2: Manual fetch in onAppear with home filter

// For locations in sidebar:
let activeHomeId = settingsManager.activeHomeId
let predicate = #Predicate<InventoryLocation> { location in
    location.home?.persistentModelID == activeHomeId
}
```

---

## 7. Implementation Phases

### Phase 1: Data Model & Migration (MVP Foundation)
**Duration:** 3-4 days
**Priority:** Must Have

| Task | Estimate | Dependencies |
|------|----------|--------------|
| Add `isPrimary` to Home model | 0.5 day | None |
| Add `home` relationship to InventoryLocation | 0.5 day | None |
| Add `home` relationship to InventoryLabel | 0.5 day | None |
| Create migration logic in ModelContainerManager | 1 day | Model changes |
| Test migration with existing data | 0.5 day | Migration logic |
| Add activeHomeId to SettingsManager | 0.5 day | None |

**Deliverables:**
- Updated SwiftData models with home relationships
- Automatic migration for existing users
- Storage for active home selection

### Phase 2: Navigation & Home Switching (MVP Core)
**Duration:** 3-4 days
**Priority:** Must Have

| Task | Estimate | Dependencies |
|------|----------|--------------|
| Update SidebarView structure with Homes section | 1 day | Phase 1 |
| Implement home selection and active home state | 0.5 day | SidebarView |
| Filter locations/labels by active home in sidebar | 1 day | Active home state |
| Update DashboardView to show active home data | 0.5 day | Active home state |
| Add "All Inventory" aggregated view | 1 day | Phase 1 |

**Deliverables:**
- New sidebar structure with homes navigation
- Home switching functionality
- All Inventory cross-home view

### Phase 3: Home Management in Settings (MVP Complete)
**Duration:** 2-3 days
**Priority:** Must Have

| Task | Estimate | Dependencies |
|------|----------|--------------|
| Restructure Settings > Home Settings | 1 day | Phase 1, Phase 2 |
| Implement "Add Home" flow | 0.5 day | Settings restructure |
| Implement home deletion with cascade | 0.5 day | Settings restructure |
| Move Labels/Locations settings under each home | 0.5 day | Settings restructure |
| Add "Set as Primary" option | 0.5 day | Settings restructure |

**Deliverables:**
- Complete home management UI in Settings
- Create, rename, delete homes
- Per-home label/location management

### Phase 4: Polish & Edge Cases (Post-MVP)
**Duration:** 2-3 days
**Priority:** Should Have

| Task | Estimate | Dependencies |
|------|----------|--------------|
| UI refinements (home badges in All Inventory) | 0.5 day | Phase 2 |
| Handle orphaned items (no location) | 0.5 day | Phase 1 |
| Add telemetry for multi-home analytics | 0.5 day | All phases |
| Comprehensive testing (unit + UI) | 1 day | All phases |
| Documentation and code review | 0.5 day | All phases |

**Deliverables:**
- Polished multi-home experience
- Analytics tracking
- Full test coverage

### Timeline Summary

```
Week 1: Phase 1 (Data Model & Migration) + Start Phase 2
Week 2: Phase 2 (Navigation) + Phase 3 (Settings)
Week 3: Phase 4 (Polish) + Testing + Release
```

**Total Estimated Duration:** 10-14 development days

---

## 8. Risks and Mitigations

### High Risk

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Data loss during migration** | Low | Critical | Backup data before migration; implement rollback capability; extensive testing |
| **CloudKit sync conflicts** | Medium | High | Use additive schema changes only; test multi-device scenarios; implement conflict resolution |
| **Performance degradation with many homes** | Low | Medium | Lazy loading; optimize queries with home filters; set reasonable home limit (10?) |

### Medium Risk

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Complex query refactoring** | High | Medium | Document all query locations; create reusable filtered fetch methods |
| **User confusion with new navigation** | Medium | Medium | Clear onboarding for multi-home users; intuitive default behavior |
| **Increased app complexity** | High | Medium | Clean separation of concerns; good documentation; code review |

### Low Risk

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Edge case: items without locations** | Low | Low | Items still belong to home through location nil handling |
| **Settings UI becoming cluttered** | Low | Low | Collapsible sections; progressive disclosure |

---

## 9. Non-Goals

The following are explicitly **out of scope** for this feature:

1. **Sharing homes between users** - No multi-user collaboration in this release
2. **Home templates** - No ability to duplicate a home's structure to a new home
3. **Bulk item transfer between homes** - Manual reassignment only
4. **Home-specific subscription tiers** - Pro subscription applies to all homes
5. **Home-specific AI analysis quotas** - AI usage is account-level
6. **Separate export per home** - Export includes all homes (future enhancement)
7. **Home sorting or reordering in sidebar** - Alphabetical order only
8. **Home archiving** - Delete only, no archive functionality
9. **Deep linking to specific homes** - URL scheme support deferred

---

## 10. Open Questions

| Question | Options | Recommendation | Status |
|----------|---------|----------------|--------|
| Should primary home designation be device-local or synced? | Synced / Local | **Synced** - consistency across devices | Pending Decision |
| Maximum number of homes allowed? | Unlimited / 5 / 10 / 20 | **10** - reasonable limit, can increase later | Pending Decision |
| Should deleting a home archive items instead of deleting? | Archive / Delete | **Delete** - simpler, users expect data removal | Pending Decision |
| How to handle "All Inventory" in item detail view? | Show home badge / Navigate to home first | **Show home badge** - maintain context | Pending Decision |
| Should labels be global or per-home? | Global / Per-Home | **Per-Home** - matches requirement, more flexible | Confirmed |

---

## Appendix A: UI Mockups Reference

### Sidebar Structure
```
+---------------------------+
| [Home Photo]              |
| Dashboard                 |
+---------------------------+
| HOMES                     |
| > Beach House             |
| > Storage Unit            |
+---------------------------+
| > All Inventory           |
+---------------------------+
| LOCATIONS                 |
| > Living Room             |
| > Kitchen                 |
| > Bedroom                 |
+---------------------------+
| LABELS                    |
| > Electronics             |
| > Furniture               |
+---------------------------+
```

### Settings > Home Settings
```
+---------------------------+
| HOME SETTINGS             |
+---------------------------+
| My House (Primary)    [>] |
+---------------------------+
| Beach House           [>] |
+---------------------------+
| Storage Unit          [>] |
+---------------------------+
| [+ Add Home]              |
+---------------------------+
```

---

## Appendix B: Analytics Events

| Event Name | Properties | Trigger |
|------------|------------|---------|
| `home_created` | home_id, is_primary, has_photo | New home created |
| `home_deleted` | home_id, items_deleted_count | Home deleted |
| `home_selected` | home_id, source (sidebar/settings) | User switches homes |
| `home_primary_changed` | old_home_id, new_home_id | Primary designation changed |
| `all_inventory_viewed` | home_count, total_items | All Inventory accessed |
| `multi_home_migration_complete` | homes_count, items_count, duration_ms | Migration finished |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-20 | PM Subagent | Initial draft |

---

**Next Steps:**
1. Review and approve PRD with stakeholders
2. Technical architecture review with iOS Architect
3. Create detailed task breakdown
4. Begin Phase 1 implementation
