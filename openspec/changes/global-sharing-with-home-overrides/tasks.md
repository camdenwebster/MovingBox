## 1. Persistence And Data Model Foundations

- [ ] 1.1 Add SQLiteData table/schema definitions for household, household membership, invite, and home access override records.
- [ ] 1.2 Add a composite uniqueness constraint for per-home overrides on `(householdId, homeId, memberId)` and implement upsert-safe write paths.
- [ ] 1.3 Add home privacy state persistence (`isPrivate` or equivalent) and ensure private flag is queryable with home summaries.
- [ ] 1.4 Update local preview/test fixtures to seed household-scoped sharing data and non-private/private home combinations.

## 2. Sharing Service And Permission Resolution

- [ ] 2.1 Implement a centralized permission resolver that evaluates membership, default household policy, and per-home override precedence.
- [ ] 2.2 Implement invite acceptance flow that assigns `member` role automatically and grants access to non-private homes by default.
- [ ] 2.3 Ensure membership revocation removes effective access to all homes and home-scoped items immediately.
- [ ] 2.4 Enforce that viewer role cannot be created, assigned, or accepted in sharing service APIs.

## 3. Home Overrides And Item Access Behavior

- [ ] 3.1 Implement owner APIs/use cases for creating, updating, and removing per-home allow/deny overrides.
- [ ] 3.2 Implement owner action to mark a home private and apply exclusion from automatic member access.
- [ ] 3.3 Update item move logic so item visibility is recalculated from destination home effective permissions.
- [ ] 3.4 Add cleanup/reconciliation for stale override rows after membership removal.

## 4. Global Sharing UX And Interaction Flows

- [ ] 4.1 Build or update global sharing settings UI to manage invites, members, and default policy (`allHomesShared` vs `ownerScopesHomes`).
- [ ] 4.2 Add enable-sharing confirmation messaging that explains private-home behavior and where to configure it.
- [ ] 4.3 Add home-level advanced access UI that shows inherited vs overridden member access state.
- [ ] 4.4 Remove or refactor conflicting home-only sharing entry points so sharing management is consistent with global-first UX.

## 5. Household-Scoped Metadata

- [ ] 5.1 Scope labels and shared global metadata to household identity instead of home identity.
- [ ] 5.2 Update metadata query paths so active household members can see household labels regardless of per-home override state.
- [ ] 5.3 Validate metadata references remain stable across member removal and re-invite flows.
- [ ] 5.4 Keep audit logs for metadata permission changes explicitly out of scope for this release.

## 6. Verification And Regression Coverage

- [ ] 6.1 Add unit tests for permission resolution precedence across both default policies plus explicit allow/deny overrides.
- [ ] 6.2 Add unit/integration tests for invite acceptance auto-member behavior with private-home exclusions.
- [ ] 6.3 Add tests for revocation, item-move visibility recalculation, and duplicate-override prevention.
- [ ] 6.4 Add UI tests for global sharing settings, private-home warning flow, and home access override interactions.
