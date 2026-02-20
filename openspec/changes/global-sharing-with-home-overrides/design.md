## Context

The proposal shifts sharing from a primarily home-scoped model to a household-scoped default, while preserving per-home flexibility. The app uses SQLiteData for local persistence with SyncEngine-based iCloud synchronization, which requires careful modeling of membership and access records plus deterministic conflict handling across devices. The design must keep UX simple for most families while supporting edge cases (private home, temporary member, blended households) without rewriting core sharing logic later.

## Goals / Non-Goals

**Goals:**
- Provide one global sharing surface for invites, membership, and default access behavior.
- Make "all homes shared" the primary mental model while allowing owner-controlled per-home overrides.
- Keep global metadata (for example labels) consistent across shared members and homes.
- Centralize permission evaluation so list/detail queries and mutations use the same access rules.
- Preserve a clear path to future granular permissions without a data-model reset.

**Non-Goals:**
- Item-level ACLs or per-field visibility controls.
- Public/external link sharing.
- Multi-household membership in a single user session.
- Full role matrix expansion beyond owner/member (viewer remains optional and deferred unless needed by specs).

## Decisions

### 1) Introduce household-scoped sharing root

Create a household sharing root (workspace) that owns:
- members
- invitations
- global sharing settings
- global metadata scope (labels and other cross-home objects)

Each home belongs to one household. Access checks start at household membership, then apply home overrides.

Alternatives considered:
- Keep only home-level membership rows and infer "global" by writing each home membership record.
  - Rejected: high write amplification, fragile sync behavior, and poor UX for "share everything."

### 2) Permission resolution uses default policy + per-home overrides

Add a global default policy on household settings:
- `allHomesShared` (default): members can access all homes unless denied on a specific home.
- `ownerScopesHomes`: members get no home access unless allowed on specific homes.

Add a per-home override record keyed by `(householdId, homeId, memberId)` with `allow` or `deny` semantics. Enforce uniqueness with a SQLite-level composite unique constraint and repository upsert behavior, while preserving deterministic conflict resolution for synchronized writes.

Permission evaluation algorithm:
1. Verify active household membership.
2. Compute baseline from global default policy.
3. Apply explicit home override if present.
4. Apply role capability checks for mutation actions.

Alternatives considered:
- Separate tables for allow-list-only vs deny-list-only modes.
  - Rejected: mode switches become data migration events and increase branching complexity.

### 3) Global metadata is household-scoped, not home-scoped

Labels and other global metadata are associated with household scope. Items reference household-scoped metadata and home ownership independently. This keeps taxonomy stable across homes and avoids duplicate label management.

Alternatives considered:
- Labels per home with optional sync between homes.
  - Rejected: user-visible inconsistency and duplicate reconciliation complexity.

### 4) UX split: global settings first, home overrides as advanced controls

Global sharing settings screen is the primary surface:
- invite/remove members
- choose default policy
- view effective membership

Home detail/settings provides an advanced "Home Access" section:
- override specific member access for that home
- show inherited vs overridden state

New homes inherit global default policy automatically.

Alternatives considered:
- Keep all sharing controls inside home settings.
  - Rejected: duplicates member management and conflicts with global metadata behavior.

### 5) Revocation and movement semantics are destination-authoritative

Removing a member from household access immediately removes effective access to all homes and metadata; lingering per-home override rows are cleaned asynchronously. When an item moves between homes, effective visibility is recalculated from destination home permissions.

Alternatives considered:
- Preserve old-home access on moved items.
  - Rejected: creates non-intuitive exceptions and weakens home boundary semantics.

## Risks / Trade-offs

- [Risk] Effective permissions become harder to reason about with inherited + override state. -> Mitigation: show "Inherited" vs "Overridden" state in UI and provide effective-access preview text per member.
- [Risk] CloudKit conflict timing may temporarily show stale override state across devices. -> Mitigation: idempotent upsert logic, last-write-wins timestamps, and refresh after writes.
- [Risk] Duplicate override rows if uniqueness rules are not enforced consistently. -> Mitigation: add a composite unique constraint in SQLite and route writes through a single sharing repository/service API.
- [Risk] Default policy changes can surprise users if many homes are affected at once. -> Mitigation: confirmation prompt summarizing impact before committing policy change.

## Migration Plan

- No production data migration is required because sharing has not been released.
- Update local/test fixture generators to include household scope and default policy.
- Add one-time compatibility mapping for any pre-release sample data that modeled home-only sharing.
- Rollback strategy: revert to previous sharing service implementation and keep data additive (household records can remain unused).

## Open Questions

- Should `viewer` be included in initial release or deferred to a follow-up capability?
    - No, let's not include a viewer role yet
- Should owners be able to mark a home "private to owner" quickly, or must they manage member overrides manually?
    - Yes, we should allow the owner to mark a home as private prior to enabling sharing. We could display an alert when enabling sharing to remind the owner that this is possible in case there is a home they don't want to share.
- Do we need audit events for membership and access changes in v1, or can this be deferred?
    - audit logs can be deferred
- Should invite acceptance automatically grant `member` role, or require owner role assignment post-acceptance?
    - Yes, member role should be automatically granted to all non-private homes upon invite acceptance.
