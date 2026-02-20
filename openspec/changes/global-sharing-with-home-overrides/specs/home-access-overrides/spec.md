## ADDED Requirements

### Requirement: Owner Can Override Member Access Per Home
The system MUST allow the owner to define explicit per-home access overrides for each member with `allow` and `deny` outcomes.

#### Scenario: Owner grants home access while default is owner-scoped
- **WHEN** household default policy is `ownerScopesHomes` and the owner creates an `allow` override for a member on a specific home
- **THEN** the member gains access to that home while remaining excluded from homes without allow overrides

#### Scenario: Owner denies one home while default is all-homes
- **WHEN** household default policy is `allHomesShared` and the owner creates a `deny` override for a member on one home
- **THEN** the member loses access to that home while retaining access to other non-private homes

### Requirement: Home Access Resolution Applies Default Then Override
The system MUST resolve home visibility by evaluating active household membership, then default household policy, then a per-home override when present.

#### Scenario: Override supersedes inherited policy
- **WHEN** a member has inherited access from default policy and a per-home deny override exists
- **THEN** the effective result for that home is no access

### Requirement: Owners Can Mark Homes Private
The system MUST allow the owner to mark individual homes as private so they are excluded from automatic member access and invite-acceptance default grants.

#### Scenario: Private home excluded from automatic grants
- **WHEN** a home is marked private and a member is invited or accepted into the household
- **THEN** the member does not receive access to that private home unless the owner adds an explicit allow override

### Requirement: Item Visibility Follows Destination Home Access
The system MUST recalculate member access for an item when that item is moved to a different home, using destination-home effective access.

#### Scenario: Item moved into denied home
- **WHEN** an item is moved from a home the member can access into a home where the member is denied
- **THEN** the member no longer has access to that item after the move completes

### Requirement: Household Revocation Removes Home Access
The system MUST remove effective access to all homes and home-scoped items when a user is removed from household membership.

#### Scenario: Member removed from household
- **WHEN** the owner revokes a member from the household
- **THEN** the user immediately loses effective access to every home and home-scoped item in that household
