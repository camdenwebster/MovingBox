# Generalized Exploratory Upgrade/Release Playbook

Use this template for iOS simulator exploratory validation.

## Inputs (confirm before run)
- Testing mode: `feature` or `release-regression`.
- Baseline ref: previous stable tag/commit.
- Target ref: commit/branch candidate.
- Simulator UDID.
- Bundle ID.
- Feature scope/oracles (feature mode only).

## Run Folder
```bash
TS="$(date +%Y%m%d-%H%M%S)"
RUN_ROOT="<repo>/.build/exploratory-upgrade/${TS}"
mkdir -p "${RUN_ROOT}"/{logs,screenshots,db,reports,commands}
```

Initialize structured run log:
```bash
cp "<skill>/references/report-log-template.json" "${RUN_ROOT}/reports/test-results.json"
```

## Environment Setup
- Run `scripts/setup_simulator_env.sh`.
- Start log capture for app subsystem.
- Record environment metadata (refs, simulator, bundle, timestamp).

## Worktrees
- Create detached worktrees for baseline and target.
- Never change refs in the main working tree.

## Baseline Phase
1. Build baseline in baseline worktree.
2. Install baseline app.
3. Launch with stable exploratory args (avoid test data preload unless intended).
4. Seed deterministic data via MCP/UI.
5. Include image-backed items:
- 2 items with primary + secondary photos,
- 1 item with at least primary photo,
- at least 1 non-photo item for control.
6. Capture phase screenshots.

## Pre-Upgrade Evidence
- App data container path.
- Source store files.
- Source counts by entity.
- Preferences snapshot.
- Image-related source markers for targeted items.

## Target Upgrade Phase
1. Build target in target worktree.
2. Install target in-place (same simulator/container).
3. Launch app for real migration path.

## Post-Upgrade Evidence
- Migration logs (success/error markers).
- Preferences/flags (migration completion and related one-time flags).
- sqlite candidate DBs and table list.
- sqlite counts by entity.
- FK integrity (`PRAGMA foreign_key_check`).
- Backup/archive verification.
- Photo migration evidence for targeted items (blob counts).
- UI screenshots confirming migrated items/photos render.

## Suggested SQL Checks
### Post photo check
```sql
SELECT i.title, COUNT(p.id) AS photoBlobCount
FROM inventoryItems i
LEFT JOIN inventoryItemPhotos p ON p.inventoryItemID = i.id
WHERE i.title IN ('<photo item A>', '<photo item B>', '<photo item C>')
GROUP BY i.id, i.title
ORDER BY i.title;
```

## Gate Policy
- `FAIL` on any:
- migration crash/hang/unrecoverable startup,
- data-loss discrepancy,
- non-empty FK violations,
- unresolved P0/P1 defects.
- `PASS` only if all gates pass with complete evidence artifacts.

## Outputs
- `reports/test-results.json`
- `reports/final-verdict.md`
- `reports/defects.md` (if failures)
- `reports/site/index.html`
- all DB, log, and screenshot artifacts under run root.

Generate static report:
```bash
"<skill>/scripts/create_report_site.sh" \
  --run-root "${RUN_ROOT}" \
  --json "${RUN_ROOT}/reports/test-results.json"
```
