# PRD: Family Sharing Invite Acceptance Flow

## Introduction

MovingBox supports family sharing via CloudKit, where `SQLiteHome` is the share root. Sharing is **per-home** — users can share individual homes with different people while keeping other homes private. Today, when an existing user accepts a share invite, it happens silently in the background with no prompt. The shared home simply appears alongside their existing homes, and there's no option to consolidate data.

This feature adds:
1. A dedicated acceptance flow for existing users joining a shared home, with the option to merge items from one of their existing homes into the shared home or just join alongside.
2. Per-home sharing management UI in `HomeDetailSettingsView` instead of the root settings.
3. Photo migration to BLOB/CKAsset storage as a prerequisite (photos currently don't sync to shared users).

## Goals

- Give existing users control over how they join a shared home (join alongside, merge items in, or start fresh)
- Move sharing UI to per-home context (`HomeDetailSettingsView`) for natural per-home sharing management
- Prevent confusing duplicate labels when merging items into a shared home
- Migrate photos to BLOB storage so shared users can actually see each other's photos
- Maintain the existing abbreviated flow for new users (no changes)

## User Stories

### US-000: Migrate photos from file URLs to CKAsset-compatible BLOBs
**Description:** As a shared user, I want to see the owner's photos (and vice versa) so that the shared inventory is complete and useful.

**Background:** Photos are currently stored as files on disk in the iCloud Drive ubiquitous container (`Images/{id}.jpg`), referenced by `imageURL: URL?` and `secondaryPhotoURLs: [String]` on `SQLiteHome`, `SQLiteInventoryLocation`, and `SQLiteInventoryItem`. iCloud Drive syncs files between the *same user's* devices but NOT to shared users — meaning shared users receive file paths that point to nothing. Photos must be migrated to BLOB storage so sqlite-data syncs them as CKAssets via CloudKit.

**Data Model:**
- New table: `photos` (`id` TEXT PK, `data` BLOB NOT NULL) — each row is a single photo's image data
- Per-entity join tables with sort ordering:
  - `inventoryItemPhotos` (`id` TEXT PK, `inventoryItemID` FK, `photoID` FK, `sortOrder` INT)
  - `homePhotos` (`id` TEXT PK, `homeID` FK, `photoID` FK, `sortOrder` INT)
  - `inventoryLocationPhotos` (`id` TEXT PK, `inventoryLocationID` FK, `photoID` FK, `sortOrder` INT)
- Remove `imageURL: URL?` and `secondaryPhotoURLs: [String]` columns from all three entity tables — no `primaryPhotoID` FK needed
- The "primary photo" is determined by querying the join table ordered by `sortOrder` and taking the first result
- When a photo is deleted and the next photo becomes primary, no FK updates are needed — the sort order handles it automatically
- The `photos` table and all join tables are included in `SyncEngine` table list so BLOBs sync as CKAssets

**Thumbnails:**
- Thumbnails are NOT stored in the database — they are derived data generated from the primary photo's BLOB
- Generated on-demand from BLOB data when first needed, cached to disk at `Thumbnails/{photoID}_thumb.jpg`
- In-memory `NSCache` provides hot-path performance (existing pattern in `OptimizedImageManager`)
- Cache keys use the **photo ID** (from `photos` table), not the entity ID
- When the primary photo changes (e.g., first photo deleted → second becomes primary), the photo ID changes → new thumbnail generated on demand, old thumbnail file orphaned and cleaned up lazily
- No iCloud Drive ubiquitous container needed for thumbnails — they're purely local cache

**Acceptance Criteria:**
- [ ] `photos` table created with `id` (TEXT PK, NOT NULL ON CONFLICT REPLACE) and `data` (BLOB NOT NULL)
- [ ] Join tables created for all three entity types with `sortOrder` column
- [ ] `imageURL` and `secondaryPhotoURLs` columns removed from `SQLiteHome`, `SQLiteInventoryLocation`, `SQLiteInventoryItem`
- [ ] Primary photo resolved by querying join table with `ORDER BY sortOrder ASC LIMIT 1` — no `primaryPhotoID` FK
- [ ] File-to-BLOB migration added to the existing SwiftData → sqlite-data migration in `SQLiteMigrationCoordinator` (runs at first launch of v2.2.0)
- [ ] Migration reads each photo file from disk, inserts as BLOB into `photos` table, creates join table entries with correct sort order (primary = 0, secondary photos = 1, 2, ...)
- [ ] `OptimizedImageManager` updated: saves/loads photos to/from BLOB storage instead of iCloud Drive files; thumbnail generation reads from BLOB data
- [ ] `PhotoManageable` protocol updated to work with photo IDs and BLOB storage instead of file URLs
- [ ] Thumbnails generated on-demand from BLOB data, cached to disk keyed by photo ID
- [ ] Old photo files and iCloud Drive `Images/` directory cleaned up after successful migration
- [ ] `photos` table and all join tables added to `SyncEngine` table list
- [ ] Shared users can see each other's photos after CloudKit sync completes
- [ ] Build succeeds

**Note:** This is a prerequisite for sharing to work correctly at all. This story can be implemented independently of the invite acceptance flow but should land in the same release (v2.2.0).

### US-001: Move sharing UI to HomeDetailSettingsView
**Description:** As a user, I want to manage sharing for each home individually from within that home's settings, rather than from a global settings page.

**Acceptance Criteria:**
- [ ] Add a "Sharing" section to `HomeDetailSettingsView` (below Organization, above Delete)
- [ ] Show sharing status for this specific home (Not Shared / Shared with N people)
- [ ] "Share This Home" button launches `UICloudSharingController` scoped to this home
- [ ] "Manage Sharing" button (if already shared) opens participant management
- [ ] "Stop Sharing" button (if owner) to revoke all access
- [ ] Participant list with roles (Owner, Member) visible in the section
- [ ] Remove or update `FamilySharingSettingsView` in root settings — it can become a summary view that links to each home's sharing settings, or be removed entirely
- [ ] Non-owners see "Shared by [Owner Name]" with option to "Leave This Home"
- [ ] Pro subscription still required to initiate sharing (gate the "Share This Home" button)
- [ ] Build succeeds

### US-002: Detect existing data when accepting share invite
**Description:** As an existing user accepting a share invite for a specific home, I want the app to recognize I have existing data so that I'm prompted with options.

**Acceptance Criteria:**
- [ ] When `SceneDelegate` receives share metadata for an already-onboarded user with existing data (any homes with items), route to the new acceptance flow instead of silently accepting
- [ ] If the onboarded user has zero data (no homes, no items), accept silently and the shared home just appears
- [ ] New users (first launch from share link) continue using the existing `JoiningShareView` abbreviated flow — no changes
- [ ] The share metadata identifies which specific home is being shared (via the root record ID)
- [ ] Build succeeds

### US-003: Present join options for existing users
**Description:** As an existing user accepting a home share invite, I want to choose how to handle my existing data relative to the shared home.

**Acceptance Criteria:**
- [ ] Full-screen flow (similar style to `JoiningShareView`) blocks app interaction until resolved
- [ ] Shows context: "You're joining [Owner Name]'s [Home Name]" — owner name from `share.owner.userIdentity.nameComponents?.formatted()`, home name from the shared record
- [ ] Three options:
  - **Join Alongside** (default/recommended) — "Keep your existing homes and add [Home Name] to your inventory"
  - **Merge Into Shared Home** — "Move items from one of your homes into [Home Name]"
  - **Start Fresh** — "Remove all your existing data and use only the shared home"
- [ ] "Join Alongside" accepts the share immediately — shared home appears alongside existing homes
- [ ] "Merge Into Shared Home" advances to home selection (US-004)
- [ ] "Start Fresh" shows destructive confirmation, then deletes all local data and accepts the share
- [ ] Build succeeds

### US-004: Select home to merge and deduplication preference
**Description:** As a user who chose to merge, I want to pick which of my existing homes to merge into the shared home, and whether to deduplicate same-name labels and locations.

**Acceptance Criteria:**
- [ ] Home picker showing all of the user's existing homes (name, item count, location count)
- [ ] After selecting a home, show deduplication choice:
  - **Merge matching names** — "Locations and labels with the same name will be combined. The owner's versions take priority."
  - **Keep all separate** — "Everything will be kept as-is. You may see duplicate names."
- [ ] Choosing either option proceeds to merge execution (US-005)
- [ ] Build succeeds

### US-005: Execute merge into shared home
**Description:** As a user merging one of my homes into a shared home, I want my items moved into the shared home cleanly.

**Acceptance Criteria:**

**Pre-merge:**
- [ ] Accept the share via `syncEngine.acceptShare(metadata:)`
- [ ] Wait for `syncEngine.isFetchingChanges` to become `false` (owner's home data now local)
- [ ] Snapshot joiner's record IDs before merge to distinguish from owner's records

**Merge with dedup (single `database.write {}` transaction):**
- [ ] **Locations:** For each of the joiner's selected home's locations that match a shared home location by name (case-insensitive): move all items from joiner's location to the matching shared location, then delete joiner's location
- [ ] **Locations (unmatched):** Move into the shared home (update `homeID` FK) — they become new locations in the shared home
- [ ] **Items:** All remaining items in the joiner's selected home get `homeID` updated to the shared home's ID
- [ ] **Labels:** For each of the joiner's labels matching a shared-home label by name (case-insensitive): reassign `inventoryItemLabels` from joiner's label to owner's label (check for duplicate join rows first), then delete joiner's label. Labels are global, so this deduplicates across the entire database.
- [ ] **Insurance policies:** For policies on the joiner's selected home matching a shared home policy by name (case-insensitive): reassign `homeInsurancePolicies`, then delete joiner's policy
- [ ] Delete the joiner's selected home after all children have been moved

**Merge without dedup:**
- [ ] Move all locations from joiner's selected home into the shared home (update `homeID`)
- [ ] Move all items (update `homeID`)
- [ ] Move insurance policy associations
- [ ] Delete the joiner's selected home
- [ ] Labels are left as-is (potential duplicates remain)

**General:**
- [ ] Other homes the joiner owns (not the selected one) remain untouched
- [ ] Indeterminate spinner during execution
- [ ] On failure, roll back transaction, show error with retry
- [ ] On success, transition to completion (US-006)
- [ ] Build succeeds

### US-006: Show completion state
**Description:** As a user who has finished the acceptance flow, I want confirmation that everything worked.

**Acceptance Criteria:**
- [ ] Success screen similar to `JoiningShareView`'s success phase (checkmark, "You're All Set!")
- [ ] Context-appropriate messaging:
  - Join Alongside: "You now have access to [Home Name]"
  - Merge: "Your items have been moved to [Home Name]" with summary (e.g., "Moved 15 items, combined 3 labels")
  - Start Fresh: "You're all set with [Home Name]"
- [ ] "Get Started" button transitions to main app
- [ ] `OnboardingManager` state is NOT modified (user was already onboarded)
- [ ] Build succeeds

### US-007: Handle share acceptance failure gracefully
**Description:** As a user experiencing issues during share acceptance, I want to retry or bail out without data loss.

**Acceptance Criteria:**
- [ ] If CloudKit share acceptance fails (network, permissions): show error with "Try Again" and "Cancel"
- [ ] Cancel dismisses the flow — user keeps their data as-is, no merge performed
- [ ] If merge transaction fails, roll back completely — no partial state
- [ ] If "Start Fresh" deletion succeeds but share acceptance fails: show specific error with retry for just the share acceptance
- [ ] Build succeeds

## Functional Requirements

- FR-0: Photos must be migrated from file URL references to BLOB storage so that sqlite-data syncs them as CKAssets — prerequisite for sharing to display photos correctly
- FR-1: Sharing is per-home — each home can be shared independently with different people
- FR-2: Sharing UI must live in `HomeDetailSettingsView`, not in root settings
- FR-3: The system must detect whether an onboarded user has existing data before accepting a share invite
- FR-4: If existing data is detected, the system must present a full-screen blocking flow with three options: Join Alongside, Merge Into Shared Home, or Start Fresh
- FR-5: "Join Alongside" simply accepts the share — shared home appears alongside existing homes with no data changes
- FR-6: "Merge Into Shared Home" must let the user select which of their homes to merge
- FR-7: "Start Fresh" must require destructive confirmation before deleting all local data
- FR-8: When merging with deduplication, name matching must be case-insensitive
- FR-9: When deduplicating, the owner's (inviter's) records take priority
- FR-10: Label deduplication is global (labels have no homeID) — reassign `inventoryItemLabels` from joiner's label to owner's matching label, then delete joiner's label
- FR-11: Location deduplication applies only within the joiner's selected home vs. the shared home
- FR-12: Insurance policy deduplication applies only to policies associated with the merging homes
- FR-13: All merge operations must execute within a single database transaction
- FR-14: Unmatched locations from the joiner's home must be moved into the shared home (not deleted)
- FR-15: The new user first-launch flow (`JoiningShareView`) must remain unchanged
- FR-16: The flow must accept the CloudKit share (via `syncEngine.acceptShare()`) only after the user has made their choice but before merge operations (merge needs the owner's data synced locally)
- FR-17: Other homes the joiner owns (not selected for merge) remain untouched and private

## Non-Goals

- No root-level "share everything" mode — sharing is per-home only
- No undo/reverse merge capability (one-way operation)
- No manual item-by-item mapping UI during merge
- No changes to the new-user abbreviated onboarding flow (`JoiningShareView`)
- No changes to the "leave share" flow (user keeps data when leaving)
- No offline merge support — share acceptance requires network
- No per-home label scoping — labels remain global, with UI-level filtering as a future enhancement

## Design Considerations

- **Sharing in HomeDetailSettingsView** — Add a "Sharing" section to the existing form. For unshared homes, show a "Share This Home" button. For shared homes, show participant list and management options. This replaces the current `FamilySharingSettingsView` or reduces it to a summary/index page.
- **Reuse `JoiningShareView` patterns** — The existing joining flow has a clean phase-based design (accepting/success/error) with animated transitions. The new flow should follow the same visual language and component patterns from `OnboardingComponents.swift`.
- **Three-option layout** — "Join Alongside" should be the visually-emphasized default (most users will want this). "Merge" is secondary. "Start Fresh" uses destructive styling.
- **Home picker for merge** — Simple list showing each home with name, item count, and location count. Tapping selects it and advances to the dedup choice.
- **Progress feedback** — Indeterminate spinner during merge execution.

## Technical Considerations

- **Home is the share root** — `SQLiteHome` has no foreign keys and is already the CloudKit share root record. All child records (locations, items) are automatically included in the share via their foreign key chain.
- **Labels are global** — Labels have no `homeID` FK. When deduplicating labels during merge, this affects the entire database, not just the shared home. This is acceptable because label names are user-facing identifiers and deduplication is opt-in.
- **Sync completion detection:** sqlite-data's `SyncEngine` exposes `isFetchingChanges` (observable). After `acceptShare()` returns, observe this becoming `false` to know the owner's home data is available locally for merge operations.
- **Owner name and home name display:** Owner name from `share.owner.userIdentity.nameComponents?.formatted()`. Home name can be fetched from the synced `SQLiteHome` record after `acceptShare()` completes and sync finishes.
- **Transaction scope:** Merge uses `database.write { db in ... }` (async) to wrap all operations in a single GRDB transaction.
- **Foreign key integrity:** When reassigning `inventoryItemLabels`, check for duplicate join rows (item already has both labels). Remove the joiner's join row before reassigning to avoid unique constraint violations.
- **Photo storage (prerequisite — US-000):** Photos must migrate from iCloud Drive file URLs to a `photos` BLOB table with per-entity join tables. sqlite-data automatically converts BLOBs to CKAssets for CloudKit sync. Thumbnails are NOT stored in DB — generated on-demand from BLOB data, cached locally by photo ID. Migration piggybacks on existing SwiftData → sqlite-data migration in `SQLiteMigrationCoordinator` (v2.2.0).
- **Default seed data (deterministic IDs):** Per sqlite-data's `NOT NULL ON CONFLICT REPLACE` constraint, records with identical UUIDs auto-replace on sync — no conflict. Dedup logic only needs name-based matching for user-created records with different UUIDs.
- **App state routing:** Add `.acceptingShareExistingUser(CKShare.Metadata)` to `AppState` enum, similar to `.joiningShare`.
- **SceneDelegate changes:** The existing-user path must route to the new flow instead of calling `syncEngine.acceptShare()` directly.
- **FamilySharingSettingsView migration:** The current `FamilySharingSettingsView` and `FamilySharingViewModel` share the "primary home." These should be refactored to either: (a) become a summary page listing all homes' sharing status with links to each `HomeDetailSettingsView`, or (b) be removed entirely with sharing managed only from within each home's settings.

## Success Metrics

- Existing users are never surprised by unexpected data appearing in their inventory
- Zero data loss during merge operations (transactional safety)
- Users can complete the acceptance flow in under 30 seconds
- Sharing UI is discoverable within each home's settings
- No increase in support requests related to sharing confusion

## Resolved Questions

1. **Sharing granularity:** Per-home, not root-level. Home is the CloudKit share root. Users can share individual homes while keeping others private.
2. **Sync completion detection:** sqlite-data's `SyncEngine` exposes `isFetchingChanges` (observable). After `acceptShare()` returns, observe this becoming `false`.
3. **Owner name display:** Available via `share.owner.userIdentity.nameComponents?.formatted()`.
4. **Progress:** Indeterminate spinner — no per-step progress needed.
5. **Photo sync:** Photos are currently file URLs and do NOT sync to shared users. Must migrate to BLOB storage (CKAsset-compatible) as a prerequisite (US-000).
6. **Deterministic ID conflicts:** Per sqlite-data's `NOT NULL ON CONFLICT REPLACE`, records with identical UUIDs auto-replace on sync. Dedup logic only needs name-based matching.
7. **Label scope:** Labels remain global (no homeID). Managed via UI-level filtering as a future enhancement. During merge, label dedup is opt-in and applies globally.

## Open Questions

None — all questions resolved.
