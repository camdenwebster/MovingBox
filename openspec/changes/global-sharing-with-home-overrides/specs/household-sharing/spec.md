## ADDED Requirements

### Requirement: Household Membership Governs Baseline Sharing
The system MUST create a household-level sharing workspace where owner and member membership records govern baseline access across all homes in the household.

#### Scenario: Member sees shared homes under all-homes default
- **WHEN** a user with `member` role is active in a household configured with `allHomesShared`
- **THEN** the user can access every non-private home in that household unless a home-specific deny override exists

### Requirement: Global Sharing Settings Control Default Home Access Policy
The system MUST provide a global sharing settings surface where the owner can choose the default home access policy for household members.

#### Scenario: Owner sets owner-scoped default
- **WHEN** the owner changes the household default policy to `ownerScopesHomes`
- **THEN** members lose inherited access to homes unless a home-specific allow override exists

### Requirement: Invite Acceptance Grants Member Access Automatically
The system MUST assign accepted invites the `member` role and grant access to all non-private homes according to household default policy at acceptance time.

#### Scenario: Invite accepted under all-homes default
- **WHEN** an invited user accepts an invite for a household configured with `allHomesShared`
- **THEN** the user is assigned `member` role and receives access to all homes that are not marked private

### Requirement: Viewer Role Is Not Supported In This Capability
The system MUST NOT expose a `viewer` role in membership creation, invitation, acceptance, or role editing for this release.

#### Scenario: Owner attempts to assign viewer role
- **WHEN** the owner opens role assignment during invite or membership management
- **THEN** the system offers only supported roles for this release and does not allow `viewer`

### Requirement: Owner Is Warned About Private Homes When Enabling Sharing
The system MUST inform owners, at the time they enable household sharing, that homes can be marked private to exclude them from default member access.

#### Scenario: Owner enables household sharing
- **WHEN** the owner turns on household sharing for the first time
- **THEN** the system presents a confirmation message that explains private-home behavior and where to configure it
