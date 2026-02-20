---
name: exploratory-tester
description: Run simulator-based exploratory testing for iOS app upgrade paths and release acceptance/regression. Use when the user asks to validate migration behavior, in-place upgrades, release readiness, or feature-level exploratory coverage with evidence artifacts, screenshots, logs, and PASS/FAIL reporting. Always confirm baseline and target versions with the user before execution.
---

# Exploratory Tester

## Confirm Scope First
1. Confirm testing mode with the user before running commands.
2. Choose one mode:
- Feature exploratory: user provides feature/area and expected outcomes.
- Release regression/acceptance: compare previous released version to current candidate.
3. Confirm version refs explicitly:
- Baseline ref (tag/commit/branch).
- Target ref (commit/branch under test).
4. Confirm simulator UDID and bundle ID.

## Prepare Environment
1. Run `scripts/setup_simulator_env.sh` from this skill.
2. Pass `--run-root <path>` so setup artifacts are recorded in the same run folder.
3. Use default image set unless the user specifies different photos.

Example:
```bash
"$SKILL_DIR/scripts/setup_simulator_env.sh" \
  --udid 4DA6503A-88E2-4019-B404-EBBB222F3038 \
  --repo-root /Users/camden.webster/dev/MovingBox \
  --run-root /Users/camden.webster/dev/MovingBox/.build/exploratory-upgrade/<timestamp>
```

## Execute Test Workflow
1. Create detached worktrees for baseline and target refs.
2. Build/install baseline.
3. Seed deterministic baseline data via MCP/UI actions.
4. Include at least one image-backed item set and one non-image stress set.
5. Capture pre-upgrade evidence (store files, counts, preferences, image markers).
6. Build/install target in-place.
7. Capture post-upgrade evidence:
- migration signals,
- flags,
- sqlite counts,
- FK check,
- backup/archive checks,
- photo migration checks,
- UI verification screenshots.
8. Produce final verdict and defects report.

Use the generalized workflow template in `references/generalized-playbook.md`.

## Reporting Rules
1. Mark release verdict `FAIL` for any data-loss discrepancy, migration crash/hang, FK violations, or unresolved P0/P1 defects.
2. Mark `PASS` only when gates pass and evidence exists for each required check.
3. Always include concrete artifact paths in final output.
