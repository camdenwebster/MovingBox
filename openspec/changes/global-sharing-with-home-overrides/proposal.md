## Why

Home-level sharing alone creates UX friction for households that want a simple "share everything" model, and it complicates global concepts such as labels and other cross-home metadata. Introducing global sharing as the default, with optional home-level scoping for exceptions, reduces user confusion now while preserving flexibility for more complex household structures.

## What Changes

- Add a global household sharing model where invited members can access all shared homes, items, and global metadata by default.
- Add owner-managed per-home access overrides so specific members can be included or excluded for individual homes.
- Define consistent behavior for global entities (for example labels) under household scope, independent of individual home membership.
- Define membership role expectations (owner/member, and optional viewer behavior) and revocation semantics across global and home-scoped access.
- Define migration and default behavior for new homes so sharing outcomes are explicit and predictable.

## Capabilities

### New Capabilities
- `household-sharing`: Manage a global sharing space where invites, membership, and default access apply across all homes and shared data.
- `home-access-overrides`: Allow owners to override the global default by scoping individual homes to specific members.
- `shared-global-metadata`: Ensure global metadata (such as labels) is shared consistently at household scope and usable across homes.

### Modified Capabilities
- None.

## Impact

- Affects data modeling for membership, access scope, and role/permission evaluation.
- Affects sharing and settings UX flows, including invite management and per-home access controls.
- Affects sync/access logic for home lists, item visibility, and global metadata consistency.
- Sharing has not been released yet - no migration necessary
- May need to remove sharing UI from the home settings view, if going to be managed in a separate sharing settings view
