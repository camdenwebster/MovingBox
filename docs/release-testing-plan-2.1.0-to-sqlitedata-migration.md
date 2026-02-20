# Release Test Plan: `2.1.0` -> Current `sqlitedata-migration` (including local WIP)

## Summary
This plan validates upgrade safety and feature correctness for:
1. SwiftData -> sqlite-data migration + photo BLOB migration
2. Multi-home and household/family sharing behavior
3. AI analysis changes (Gemini Flash via OpenRouter/AIProxy), including multi-photo and video analysis

It is **strict-blocking**: any unmitigated migration/data-loss P1 blocks release.

## Scope (Compared to `2.1.0`)
- Baseline tag: `2.1.0` (`7d712e7`, Dec 29, 2025)
- Target under test: current branch `sqlitedata-migration` **plus local WIP**
- Delta size (committed): large refactor (216 product/test files touched in core app/test paths)
- Additional local WIP: household sharing overrides, new tables, new tests, and test-plan updates

## Important API / Schema / Interface Changes
- Persistence layer replaced:
  - SwiftData models removed; sqlite-data tables introduced in `/Users/camden.webster/dev/MovingBox/MovingBox/Services/DatabaseManager.swift`
- Upgrade/runtime migration coordinators:
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/SQLiteMigrationCoordinator.swift`
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/PhotoBlobMigrationCoordinator.swift`
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/CloudKitRecoveryCoordinator.swift`
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/HomeCullingManager.swift`
- Multi-home and sharing schema additions:
  - `homes.householdID`, `homes.isPrivate`
  - new tables: `households`, `householdMembers`, `householdInvites`, `homeAccessOverrides`
- AI model behavior:
  - effective model now `google/gemini-3-flash-preview` (`SettingsManager.effectiveAIModel`)
  - multi-photo + multi-item + video analysis path expanded

## Test Environments (Required)
1. Simulator:
   - iPhone 17 Pro simulator (`4DA6503A-88E2-4019-B404-EBBB222F3038`)
2. Physical device A:
   - owner account
3. Physical device B:
   - second Apple ID invited into sharing flow
4. Data sets:
   - deterministic seeded fixtures
   - at least one anonymized real 2.1.0 backup/profile

## Release Gates
1. No unresolved P0/P1 in migration, sync, home assignment, or AI capture flows
2. All required automated suites pass (below)
3. All migration scenarios pass with count/integrity checks
4. All exploratory charters executed with logged evidence and outcomes
5. No unresolved data-loss discrepancy (counts/photos/relationships)

## Automated Regression Execution
1. Build gate:
```bash
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift
```
2. Unit suite gate:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift
```
3. UI smoke gate:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData -testPlan SmokeTests 2>&1 | xcsift
```
4. UI release gate:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData -testPlan ReleaseTests 2>&1 | xcsift
```
5. Focus suites (must pass):
- `HouseholdSharingServiceTests`
- `SQLiteSchemaTests`, `SQLiteModelCRUDTests`, `SQLiteRelationshipTests`
- `SQLiteMigrationCoordinatorTests`
- `MultiHomeNavigationUITests`
- `FamilySharingUITests`
- `MultiItemCaptureFlowUITests`

## Migration Validation Matrix (2.1.0 -> target)
1. **Core text/string migration**
- Install 2.1.0, create data with long strings/special chars/empty fields
- Upgrade in-place to target
- Verify home/location/item/label/policy counts and representative field equality

2. **Photo file -> BLOB migration**
- 2.1.0 dataset with primary + secondary photos across homes/locations/items
- Upgrade and verify:
  - photos render in UI
  - `inventoryItemPhotos/homePhotos/inventoryLocationPhotos` row counts > 0 where expected
  - legacy URL columns nulled/`[]` post migration

3. **Single-home -> multi-home promotion**
- 2.1.0 store with one real home + phantom/invalid home records (seeded fixture)
- Upgrade and verify:
  - correct primary home survives
  - phantom empty homes culled
  - orphaned items/locations assigned per fallback rules

4. **Stranded iCloud CoreData zone recovery**
- New install/no local DB with old zone data present
- Verify prompt, both branches:
  - Recover Data path imports records and cleans old zone
  - Start Fresh path marks complete and deletes old zone
- Verify ability to create new synced records after recovery/cleanup

5. **Retry/failure safety**
- Induce migration failure condition fixture (corrupt/missing critical table shape)
- Verify app does not destroy old source, surfaces migration error, respects retry cap behavior

## Regression Areas Beyond Migration
1. Multi-home navigation/filtering/stat cards and item move between homes
2. Global labels and label assignment behavior across homes/households
3. Import/export data flows with sqlite schema
4. Data deletion flows and post-delete reseeding/default-home safety
5. Family sharing:
   - enable/disable sharing
   - invites accept/revoke
   - private-home toggle and per-member overrides
6. AI scan flows:
   - single photo
   - multi-photo same item
   - multi-item image detection/edit/reanalyze
   - video analysis and deduplication output consistency

## Exploratory Charters (Required)
1. **Migration Integrity Stress Charter**
- Mission: Find silent data loss/mis-mapping in upgrade
- Tactics: messy text fields, null-heavy records, mixed relationships, repeated upgrades
- Oracle: counts, FK checks, UI parity, no crash/hang

2. **Photo Survival Charter**
- Mission: Break photo BLOB migration
- Tactics: missing files, moved files, large photos, mixed primary/secondary
- Oracle: expected failures logged, no unrelated loss, display remains correct

3. **Home Canonicalization Charter**
- Mission: Catch wrong primary home and bad culling decisions
- Tactics: default-named homes, custom metadata, empty homes, orphaned items
- Oracle: deterministic active home and item visibility

4. **CloudKit Recovery & Space Charter**
- Mission: Catch orphaned zone and post-recovery write failures
- Tactics: recover/fresh branches, network interruption, repeated launch
- Oracle: old zone deletion behavior, new object creation still works

5. **Sharing Permissions Charter**
- Mission: Validate household access policy + overrides under real devices
- Tactics: owner-scoped vs all-shared, private home toggles, revoke/reinvite
- Oracle: access is enforceable and predictable in both UI and data

6. **Gemini AI Robustness Charter**
- Mission: Break multi-item extraction with real-world noisy inputs
- Tactics: clutter, glare, low light, similar objects, branded text, price tags
- Oracle: no malformed responses, graceful fallback/retry, usable results

7. **Video Analysis Charter**
- Mission: Validate batching, dedupe, and narration-assisted detection
- Tactics: short/long clips, repeated pans, partial occlusion, speech/no speech
- Oracle: stable detected counts, no duplicate explosions, responsive progress UI

## Evidence to Capture for Every Scenario
1. App logs filtered by subsystem:
```bash
xcrun simctl spawn 4DA6503A-88E2-4019-B404-EBBB222F3038 log stream --predicate 'subsystem == "com.mothersound.movingbox"'
```
2. Before/after entity counts and FK checks from simulator DB container
3. Screenshots/video for each failed assertion
4. Migration/recovery telemetry events observed in logs

## Known Coverage Gaps To Manually Compensate
1. Photo BLOB migration lacks deep end-to-end automated verification
2. CloudKit recovery is lightly unit-tested but needs real multi-account/device validation
3. Some UI areas still skip/stub tests; these must be explicitly covered in exploratory runs

## Assumptions and Defaults
1. Plan targets current branch **including local WIP** files
2. Two physical devices and two Apple IDs are available
3. At least one anonymized real 2.1.0 dataset is available
4. Release decision is strict-blocking for migration/data integrity risks
5. Simulator remains on configured UDID/device as documented in repo
