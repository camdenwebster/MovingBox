## ADDED Requirements

### Requirement: Labels Are Scoped To Household
The system MUST scope labels and other global metadata to the household, not to individual homes.

#### Scenario: Label created in one home context
- **WHEN** a member creates a label while viewing items in one home
- **THEN** that label is available for use in every home the member can access within the same household

### Requirement: Metadata Visibility Is Based On Household Membership
The system MUST grant metadata visibility to active household members regardless of per-home overrides, while still enforcing home access for item visibility.

#### Scenario: Member denied one home still sees household labels
- **WHEN** a member is denied access to one home but remains an active household member
- **THEN** the member can still see and use household labels in homes they can access

### Requirement: Metadata Consistency Survives Sync And Sharing Changes
The system MUST preserve household metadata identity and references across sync events and membership changes.

#### Scenario: Member removed and later re-added
- **WHEN** a member is removed from a household and later re-invited and accepted
- **THEN** existing household labels remain consistent and usable without creating duplicate household-level label definitions

### Requirement: Audit Logs For Metadata Permission Changes Are Deferred
The system MUST NOT require audit log records for metadata access and role changes in this release.

#### Scenario: Membership change occurs
- **WHEN** an owner adds, removes, or re-invites a member
- **THEN** the system applies metadata visibility rules without requiring user-visible audit history artifacts
