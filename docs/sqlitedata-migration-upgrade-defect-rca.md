# sqlite-data Migration Upgrade Defect RCA (`2.1.0` -> current branch)

Run analyzed: `/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/20260220-063316`

## Defect UPGRADE-101 (Migration aborts: "zero homes")

### Observed
- Migration exits with:
  - `Migration produced zero homes from non-empty store — aborting`
  - `sqlite-data: Migration failed`
- `com.mothersound.movingbox.sqlitedata.migration.complete` is not set.

### Evidence
- Pre-upgrade CoreData counts: `ZHOME=0`, `ZINVENTORYITEM=6`, `ZINVENTORYLOCATION=3`
  - `/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/20260220-063316/db/pre-coredata-counts.txt`
- Failure logs:
  - `/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/20260220-063316/logs/app-subsystem.log`

### Root cause
- `SQLiteMigrationCoordinator.migrateIfNeeded` hard-fails any non-empty store when `stats.homes == 0`.
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/SQLiteMigrationCoordinator.swift:101`
- That assumption is not always true for legacy data shapes (items/locations present while `ZHOME` is empty), so valid legacy datasets are rejected.

## Defect UPGRADE-102 (Location count inflation 3 -> 15)

### Observed
- Pre-upgrade locations: `3`
- Post-upgrade `inventoryLocations`: `15`

### Evidence
- Count files:
  - `/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/20260220-063316/db/pre-coredata-counts.txt`
  - `/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/20260220-063316/db/post-sqlite-counts.txt`
- Post DB rows show 3 migrated legacy locations plus 12 seeded default rooms:
  - `Living Room`, `Garage`, `Office` exist with `homeID = NULL`
  - 12 default rooms exist with `homeID = aaaaaaaa-0001-0000-0000-000000000001`

### Root cause
- Migration writes records inside `performMigration(...)` transaction and commits before the `homes == 0` sanity check is applied.
  - write path: `/Users/camden.webster/dev/MovingBox/MovingBox/Services/SQLiteMigrationCoordinator.swift:203`
  - abort path: `/Users/camden.webster/dev/MovingBox/MovingBox/Services/SQLiteMigrationCoordinator.swift:105`
- After migration reports error, startup still runs default-home safety seeding when `homeCount == 0`, inserting one home and `TestData.defaultRooms` (12 rows).
  - `/Users/camden.webster/dev/MovingBox/MovingBox/MovingBoxApp.swift:352`
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/TestData.swift:38`
- Net effect: `3` migrated locations + `12` seeded rooms = `15`.

## Defect UPGRADE-103 (No `SwiftDataBackup` archive)

### Observed
- `SwiftDataBackup` directory absent after upgrade attempt.

### Evidence
- `/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/20260220-063316/db/post-swiftdata-backup-files.txt`

### Root cause
- `archiveOldStore()` only runs on success path after validation.
  - `/Users/camden.webster/dev/MovingBox/MovingBox/Services/SQLiteMigrationCoordinator.swift:111`
  - archive function: `/Users/camden.webster/dev/MovingBox/MovingBox/Services/SQLiteMigrationCoordinator.swift:933`
- Because UPGRADE-101 aborts migration first, archival never executes.

## Cross-defect causal chain
1. Legacy dataset has items/locations but `ZHOME=0`.
2. Migration writes locations/items into sqlite-data, then aborts due to `homes == 0`.
3. App startup default-seeds a home + 12 rooms (`homeCount == 0` safety net).
4. Counts inflate (UPGRADE-102), migration flag remains unset, and archive step is skipped (UPGRADE-103).

## Why migration flags can appear "already present" in exploratory runs
- UserDefaults and app container data persist across simulator sessions unless explicitly erased/uninstalled.
- Reusing a previously migrated simulator/container can make `...sqlitedata.migration.complete` appear set before a new test cycle.
- Playbook now requires `xcrun simctl erase all` before setup to prevent this contamination.
