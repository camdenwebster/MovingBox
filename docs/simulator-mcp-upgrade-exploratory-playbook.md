# MCP-Driven Simulator Upgrade Exploratory Playbook (`2.1.0` -> `main`)

## Purpose and Scope
This playbook defines a deterministic procedure for a coding agent to perform exploratory upgrade testing in the iOS Simulator using iOS Simulator MCP interactions.

Primary goals:
1. Build and install `2.1.0`.
2. Create baseline user data in the simulator via MCP-driven UI interactions.
3. Build and install current `main` in-place over the same app install to simulate upgrade.
4. Verify migration behavior and exploratory charter outcomes.
5. Produce strict pass/fail output with evidence artifacts.

Out of scope:
1. Physical-device-only family sharing validation.
2. Real multi-Apple-ID CloudKit invite acceptance.

## Hard Preconditions
1. Simulator UDID: `4DA6503A-88E2-4019-B404-EBBB222F3038`.
2. Bundle ID: `com.mothersound.movingbox`.
3. Local git contains tag `2.1.0` and branch `main`.
4. Do not perform in-place `git checkout` in the current repo root (working tree may be dirty).
5. iOS Simulator MCP is available and supports:
   - `open_simulator`
   - `get_booted_sim_id`
   - `ui_describe_all`
   - `ui_tap`
   - `ui_type`
   - `ui_swipe`
   - `launch_app`
   - `screenshot`
6. CLI tools available: `git`, `xcodebuild`, `xcrun`, `sqlite3`, `plutil`, `find`.

## Safety Rules for Dirty Working Tree
1. Never run `git checkout 2.1.0` or `git checkout main` in `/Users/camden.webster/dev/MovingBox`.
2. Always use detached worktrees:
   - `/tmp/movingbox-v210`
   - `/tmp/movingbox-main`
3. Do not use destructive git commands (`reset --hard`, checkout file rewrites) in the primary working tree.

## Environment Setup
1. Create timestamped run root:
```bash
TS="$(date +%Y%m%d-%H%M%S)"
RUN_ROOT="/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/${TS}"
mkdir -p "${RUN_ROOT}"/{logs,screenshots,db,reports,commands}
```
2. Erase all simulators to guarantee a clean state before exploratory testing:
```bash
xcrun simctl erase all
```
3. Boot simulator once:
```bash
xcrun simctl boot 4DA6503A-88E2-4019-B404-EBBB222F3038 || true
open -a Simulator
```
4. Start subsystem log stream to file:
```bash
xcrun simctl spawn 4DA6503A-88E2-4019-B404-EBBB222F3038 \
  log stream --predicate 'subsystem == "com.mothersound.movingbox"' \
  | tee "${RUN_ROOT}/logs/app-subsystem.log"
```
5. Record environment metadata:
```bash
{
  echo "timestamp=${TS}"
  echo "udid=4DA6503A-88E2-4019-B404-EBBB222F3038"
  echo "bundle=com.mothersound.movingbox"
  git -C /Users/camden.webster/dev/MovingBox rev-parse --short HEAD
  git -C /Users/camden.webster/dev/MovingBox rev-parse --short 2.1.0
} | tee "${RUN_ROOT}/reports/environment.txt"
```

## Worktree Layout
Create detached worktrees for baseline and target:
```bash
git -C /Users/camden.webster/dev/MovingBox worktree remove /tmp/movingbox-v210 --force 2>/dev/null || true
git -C /Users/camden.webster/dev/MovingBox worktree remove /tmp/movingbox-main --force 2>/dev/null || true

git -C /Users/camden.webster/dev/MovingBox worktree add --detach /tmp/movingbox-v210 2.1.0
git -C /Users/camden.webster/dev/MovingBox worktree add --detach /tmp/movingbox-main main

git -C /tmp/movingbox-v210 rev-parse --short HEAD | tee "${RUN_ROOT}/reports/v210-commit.txt"
git -C /tmp/movingbox-main rev-parse --short HEAD | tee "${RUN_ROOT}/reports/main-commit.txt"
```

## Phase 1: Build + Install `2.1.0`
1. Build from `/tmp/movingbox-v210`:
```bash
cd /tmp/movingbox-v210
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox \
  -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' \
  -derivedDataPath ./.build/DerivedData 2>&1 | xcsift \
  | tee "${RUN_ROOT}/logs/build-v210.log"
```
2. Install app:
```bash
xcrun simctl install 4DA6503A-88E2-4019-B404-EBBB222F3038 \
  /tmp/movingbox-v210/.build/DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app
```
3. Launch with version-correct exploratory args (no test data preload):
```bash
xcrun simctl launch 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox \
  --args Skip-Onboarding Disable-Animations UI-Testing-Mock-Camera Is-Pro Mock-OpenAI
```
4. MCP initialization:
   - `open_simulator`
   - `get_booted_sim_id` and verify expected UDID.

## Phase 2: MCP-Driven Baseline Data Creation on `2.1.0`
Use MCP for all UI interactions.

### MCP Interaction Loop
For each UI step:
1. Call `ui_describe_all`.
2. Identify target control coordinates by label/identifier.
3. Call `ui_tap` (or `ui_type`/`ui_swipe`).
4. Re-run `ui_describe_all` to verify transition.
5. On mismatch, retry up to 3 times before logging defect.

### Deterministic Baseline Dataset
Create the following data:
1. Homes:
   - `My Home` (default-like)
   - `Upgrade-Probe Home` (customized)
2. Locations (3 total):
   - `Living Room` in `My Home`
   - `Garage` in `My Home`
   - `Office` in `Upgrade-Probe Home`
3. Items (6 total):
   - `Lamp #1`
   - `Router/Modem Combo`
   - `Toolbox (Heavy)`
   - `Unicode Test - Cafe`
   - `Long Text Item - Lorem ipsum ...` (very long notes/description)
   - `Orphan Candidate` (save without location)
4. Photos:
   - At least 2 items with primary + secondary photos.
5. Field stress:
   - Special characters: `#`, `/`, parentheses, long strings.

### Required MCP Evidence During Data Creation
Capture screenshots via `screenshot` after each checkpoint:
1. Home list with 2 homes.
2. Location list showing 3 locations.
3. Item list showing 6 items.
4. Detail view for each multi-photo item.
5. Detail view for `Orphan Candidate`.

Save screenshots in:
`/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/<timestamp>/screenshots/phase2-*`

## Phase 3: Capture Pre-Upgrade Evidence
1. Resolve app data container:
```bash
DATA_CONTAINER="$(xcrun simctl get_app_container 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox data)"
echo "${DATA_CONTAINER}" | tee "${RUN_ROOT}/reports/data-container.txt"
```
2. Locate SwiftData store:
```bash
find "${DATA_CONTAINER}/Library/Application Support" -maxdepth 2 -type f \
  \( -name 'default.store' -o -name 'default.store-wal' -o -name 'default.store-shm' \) \
  | tee "${RUN_ROOT}/db/pre-swiftdata-store-files.txt"
```
3. Record pre-upgrade CoreData counts (from `default.store`):
```bash
STORE_PATH="${DATA_CONTAINER}/Library/Application Support/default.store"
sqlite3 "${STORE_PATH}" <<'SQL' | tee "${RUN_ROOT}/db/pre-coredata-counts.txt"
.headers on
.mode column
SELECT 'ZHOME' AS table_name, COUNT(*) AS count FROM ZHOME
UNION ALL
SELECT 'ZINVENTORYITEM', COUNT(*) FROM ZINVENTORYITEM
UNION ALL
SELECT 'ZINVENTORYLOCATION', COUNT(*) FROM ZINVENTORYLOCATION
UNION ALL
SELECT 'ZINVENTORYLABEL', COUNT(*) FROM ZINVENTORYLABEL
UNION ALL
SELECT 'ZINSURANCEPOLICY', COUNT(*) FROM ZINSURANCEPOLICY;
SQL
```
4. Record pre-upgrade app preferences snapshot:
```bash
plutil -p "${DATA_CONTAINER}/Library/Preferences/com.mothersound.movingbox.plist" \
  | tee "${RUN_ROOT}/db/pre-preferences.txt"
```

## Phase 4: Build + Install `main` In-Place (Upgrade Simulation)
1. Build from `/tmp/movingbox-main`:
```bash
cd /tmp/movingbox-main
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox \
  -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' \
  -derivedDataPath ./.build/DerivedData 2>&1 | xcsift \
  | tee "${RUN_ROOT}/logs/build-main.log"
```
2. Install in-place (same simulator, same bundle, no uninstall/reset):
```bash
xcrun simctl install 4DA6503A-88E2-4019-B404-EBBB222F3038 \
  /tmp/movingbox-main/.build/DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app
```
3. Launch for real migration path:
```bash
xcrun simctl launch 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox \
  --args Skip-Onboarding Disable-Animations UI-Testing-Mock-Camera Is-Pro
```
Important:
1. Do not pass `Use-Test-Data`.
2. Do not pass `Disable-Persistence`.
3. Let migration run at startup.

## Phase 5: Post-Upgrade Verification Matrix
Verify each item below and record `PASS` or `FAIL` in final report.

### A. Migration Signals
1. `app-subsystem.log` contains:
   - `Migration.success` or equivalent successful migration logs.
   - No terminal `Migration.error`.
2. `PhotoMigration.success` present when applicable.

### B. UserDefaults Flags
Read preferences:
```bash
plutil -p "${DATA_CONTAINER}/Library/Preferences/com.mothersound.movingbox.plist" \
  | tee "${RUN_ROOT}/db/post-preferences.txt"
```
Confirm:
1. `com.mothersound.movingbox.sqlitedata.migration.complete` is true.
2. `com.mothersound.movingbox.photo.blob.migration.complete` is true or migration not needed.
3. `com.mothersound.movingbox.homeCulling.2_2_0.complete` exists after first launch.

### C. sqlite-data Presence and Counts
Find candidate sqlite DB:
```bash
find "${DATA_CONTAINER}/Library/Application Support" -maxdepth 3 -type f -name '*.sqlite' \
  | tee "${RUN_ROOT}/db/post-sqlite-candidates.txt"
```
For each candidate, list tables and select the DB containing `homes` and `inventoryItems`.

Run count + integrity checks:
```bash
SQLITE_DB="<resolved sqlite-data db path>"
sqlite3 "${SQLITE_DB}" <<'SQL' | tee "${RUN_ROOT}/db/post-sqlite-counts.txt"
.headers on
.mode column
SELECT 'homes' AS table_name, COUNT(*) AS count FROM homes
UNION ALL
SELECT 'inventoryItems', COUNT(*) FROM inventoryItems
UNION ALL
SELECT 'inventoryLocations', COUNT(*) FROM inventoryLocations
UNION ALL
SELECT 'inventoryLabels', COUNT(*) FROM inventoryLabels
UNION ALL
SELECT 'insurancePolicies', COUNT(*) FROM insurancePolicies
UNION ALL
SELECT 'inventoryItemPhotos', COUNT(*) FROM inventoryItemPhotos
UNION ALL
SELECT 'homePhotos', COUNT(*) FROM homePhotos
UNION ALL
SELECT 'inventoryLocationPhotos', COUNT(*) FROM inventoryLocationPhotos;
SQL
```

```bash
sqlite3 "${SQLITE_DB}" 'PRAGMA foreign_key_check;' \
  | tee "${RUN_ROOT}/db/post-fk-check.txt"
```
Pass condition: `post-fk-check.txt` is empty.

### D. SwiftData Archive Validation
Confirm old store moved to backup:
```bash
find "${DATA_CONTAINER}/Library/Application Support/SwiftDataBackup" -maxdepth 2 -type f \
  | tee "${RUN_ROOT}/db/post-swiftdata-backup-files.txt"
```

### E. UI-Level Validation via MCP
Use MCP to verify:
1. All expected homes/locations/items visible.
2. Multi-photo items still display photos.
3. Orphan-prone item exists and is viewable/editable.
4. No startup migration error alert appears.

Capture screenshots:
`phase5-homes.png`, `phase5-locations.png`, `phase5-items.png`, `phase5-item-detail-photos.png`.

## Phase 6: Exploratory Charters (MCP Execution)
Each charter must include:
1. Objective.
2. Steps (MCP-driven).
3. Oracle checks.
4. Evidence artifact paths.
5. Verdict.

### 1. Migration Integrity Stress
Objective: detect silent data loss/mis-mapping.
Checks:
1. Pre/post count parity by entity.
2. Representative string fields preserved.
3. No FK violations.

### 2. Photo Survival
Objective: verify photo URL -> BLOB migration correctness.
Checks:
1. Photo tables populated when baseline had photos.
2. Legacy URL columns cleared where expected.
3. UI renders migrated photos.

### 3. Home Canonicalization
Objective: validate primary/active home behavior after multi-home migration.
Checks:
1. Expected primary/default home remains valid.
2. Sidebar/home switching remains stable.
3. No unexpected phantom homes in visible list.

### 4. CloudKit Recovery (Simulator-Testable Subset)
Objective: validate non-blocking recovery paths that do not require second Apple ID.
Checks:
1. App startup does not deadlock when probe returns none/error.
2. No fatal errors from recovery coordinator logs.
3. Local data CRUD still works post startup.
Residual risk: true stranded-zone recovery path requires device/account scenarios.

### 5. Sharing Permission (Simulator-Testable Subset)
Objective: verify local household policy and override UI semantics.
Checks:
1. Toggle private home and confirm state persistence.
2. Create local invite/member representation where flow supports it.
3. Override controls update state without data corruption.
Residual risk: real invite acceptance and cross-account sync not covered.

### 6. Gemini/Multi-Item Flow Sanity
Objective: ensure analysis workflows still function after migration.
Setup:
1. For deterministic behavior, run with mocked AI path where supported by target build.
Checks:
1. Multi-item capture flow opens, analyzes, and allows selection/edit/reanalyze.
2. No malformed/empty UI state crashes.

### 7. Video Analysis and Dedupe Sanity
Objective: verify video flow remains functional after migration.
Checks:
1. Video selection opens and proceeds through processing stages.
2. Item list appears with stable counts.
3. Reanalyze/cancel controls work.

## Evidence Capture Requirements
Mandatory artifacts under `${RUN_ROOT}`:
1. `logs/build-v210.log`
2. `logs/build-main.log`
3. `logs/app-subsystem.log`
4. `db/pre-coredata-counts.txt`
5. `db/post-sqlite-counts.txt`
6. `db/post-fk-check.txt`
7. `db/pre-preferences.txt`
8. `db/post-preferences.txt`
9. `db/post-swiftdata-backup-files.txt`
10. `screenshots/*.png`
11. `reports/final-verdict.md`
12. `reports/defects.md` (if any failures)

## Pass/Fail Gates and Severity Policy
Strict blocking policy:
1. Any data-loss discrepancy -> `FAIL`.
2. Any non-empty FK check -> `FAIL`.
3. Migration crash, hang, or unrecoverable startup error -> `FAIL`.
4. Any unresolved P1 issue -> `FAIL`.

Severity:
1. P0: crash/data corruption/security issue.
2. P1: migration correctness risk or user-facing core flow broken.
3. P2: non-blocking defect with workaround.
4. P3: cosmetic or low impact.

Release verdict:
1. `PASS`: all gates pass, no unresolved P0/P1.
2. `FAIL`: any gate fails or unresolved P0/P1 exists.

## Failure Triage Workflow
For each defect, append to `reports/defects.md` using template:

```md
## DEFECT <id>
- Severity: P0|P1|P2|P3
- Area: Migration|Photos|Homes|Sharing|AI|Video|Startup
- Repro Steps:
  1. ...
  2. ...
- Expected:
- Actual:
- Evidence:
  - Log: <path>
  - Screenshot: <path>
  - DB output: <path>
- Suspected Component:
- Blocking for release: Yes|No
```

## Cleanup and Re-run Procedure
Non-destructive cleanup:
1. Stop running app:
```bash
xcrun simctl terminate 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox || true
```
2. Remove app only from simulator (does not erase whole simulator):
```bash
xcrun simctl uninstall 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox || true
```
3. Remove temporary worktrees:
```bash
git -C /Users/camden.webster/dev/MovingBox worktree remove /tmp/movingbox-v210 --force || true
git -C /Users/camden.webster/dev/MovingBox worktree remove /tmp/movingbox-main --force || true
```
4. Preserve run artifacts in `.build/exploratory-upgrade/<timestamp>/`.

Fresh rerun:
1. Create new timestamped `RUN_ROOT`.
2. Run `xcrun simctl erase all`.
3. Recreate worktrees.
4. Repeat from Environment Setup.

## Appendix: Copy-Paste Commands

### A. One-shot setup
```bash
TS="$(date +%Y%m%d-%H%M%S)"
RUN_ROOT="/Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/${TS}"
mkdir -p "${RUN_ROOT}"/{logs,screenshots,db,reports,commands}
xcrun simctl erase all
xcrun simctl boot 4DA6503A-88E2-4019-B404-EBBB222F3038 || true
open -a Simulator
```

### B. Worktrees
```bash
git -C /Users/camden.webster/dev/MovingBox worktree remove /tmp/movingbox-v210 --force 2>/dev/null || true
git -C /Users/camden.webster/dev/MovingBox worktree remove /tmp/movingbox-main --force 2>/dev/null || true
git -C /Users/camden.webster/dev/MovingBox worktree add --detach /tmp/movingbox-v210 2.1.0
git -C /Users/camden.webster/dev/MovingBox worktree add --detach /tmp/movingbox-main main
```

### C. Build/install `2.1.0`
```bash
cd /tmp/movingbox-v210
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox \
  -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' \
  -derivedDataPath ./.build/DerivedData 2>&1 | xcsift \
  | tee "${RUN_ROOT}/logs/build-v210.log"
xcrun simctl install 4DA6503A-88E2-4019-B404-EBBB222F3038 \
  /tmp/movingbox-v210/.build/DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app
xcrun simctl launch 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox \
  --args Skip-Onboarding Disable-Animations UI-Testing-Mock-Camera Is-Pro Mock-OpenAI
```

### D. Build/install `main` in-place
```bash
cd /tmp/movingbox-main
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox \
  -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' \
  -derivedDataPath ./.build/DerivedData 2>&1 | xcsift \
  | tee "${RUN_ROOT}/logs/build-main.log"
xcrun simctl install 4DA6503A-88E2-4019-B404-EBBB222F3038 \
  /tmp/movingbox-main/.build/DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app
xcrun simctl launch 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox \
  --args Skip-Onboarding Disable-Animations UI-Testing-Mock-Camera Is-Pro
```

### E. Data container + DB quick checks
```bash
DATA_CONTAINER="$(xcrun simctl get_app_container 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox data)"
echo "${DATA_CONTAINER}"
find "${DATA_CONTAINER}/Library/Application Support" -maxdepth 3 -type f | sort
plutil -p "${DATA_CONTAINER}/Library/Preferences/com.mothersound.movingbox.plist"
```

### F. Final verdict report skeleton
```md
# Upgrade Exploratory Verdict
- Run root: <path>
- Baseline commit (2.1.0): <sha>
- Target commit (main): <sha>
- Overall Verdict: PASS|FAIL

## Gate Results
1. Migration signals: PASS|FAIL
2. Data parity: PASS|FAIL
3. FK integrity: PASS|FAIL
4. Photo migration: PASS|FAIL
5. Exploratory charters: PASS|FAIL

## Residual Risks
1. Physical-device-only sharing and real multi-account CloudKit flows not covered by simulator-only run.
```
