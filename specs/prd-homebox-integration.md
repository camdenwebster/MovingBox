# Product Requirements Document: HomeBox Integration

## Introduction/Overview

This feature enables users to synchronize their MovingBox inventory data with a self-hosted HomeBox instance as an alternative to iCloud sync. HomeBox is an open-source home inventory management system that allows users to maintain complete control over their data. MovingBox will act as an AI-powered input device for HomeBox, leveraging MovingBox's advanced camera and AI capabilities while allowing users to store and manage their data on their own infrastructure.

**Problem Solved**: Privacy-conscious and tech-savvy users want to maintain control over their inventory data without relying on cloud services. They need a way to use MovingBox's AI features while keeping their data on self-hosted infrastructure.

**Goal**: Provide a seamless integration with HomeBox that allows users to leverage MovingBox's AI capabilities while maintaining data sovereignty through self-hosted infrastructure.

## Goals

1. Enable users to choose between iCloud and HomeBox as their sync backend
2. Implement bidirectional synchronization between MovingBox and HomeBox
3. Support authentication to HomeBox instances via web-based OAuth or username/password
4. Maintain existing SwiftData local storage for offline capability
5. Map MovingBox data models to HomeBox equivalents with best-effort field matching
6. Provide real-time sync with conflict resolution
7. Support photo synchronization and attachment management
8. Ensure seamless user experience with minimal configuration required

## User Stories

1. **As a privacy-conscious user**, I want to sync my inventory data to my own HomeBox server so that I maintain complete control over my data.

2. **As a tech-savvy user**, I want to use MovingBox's AI capabilities to quickly catalog items and have them automatically appear in my HomeBox instance so that I can leverage the best of both applications.

3. **As a user with existing HomeBox data**, I want MovingBox to import my existing items so that I can continue building on my current inventory.

4. **As a user switching sync providers**, I want to easily migrate from iCloud to HomeBox (or vice versa) without losing any data so that I have flexibility in my data storage choices.

5. **As a user with multiple devices**, I want my MovingBox changes to sync to HomeBox and appear on other devices so that my inventory stays consistent across all platforms.

6. **As a user with poor internet connectivity**, I want to continue using MovingBox offline and have changes sync when connectivity returns so that network issues don't interrupt my workflow.

## Functional Requirements

### Sync Service Selection
1. A new "Sync Service" picker must be added to the Settings view under "Sync & Backup"
2. The picker must offer options for "iCloud" and "HomeBox"
3. "iCloud" must be the default selection for all users
4. Users must be able to switch between sync services without data loss
5. The UI must clearly indicate which sync service is currently active

### HomeBox Configuration
6. When "HomeBox" is selected, a URL text field must appear for entering the HomeBox server URL
7. The URL field must validate that the entered URL is a valid HomeBox instance
8. A "Login" button must be provided to initiate authentication with the HomeBox server
9. The system must support both OAuth-based authentication (via ASWebAuthenticationSession) and username/password authentication
10. Authentication credentials must be securely stored in the iOS Keychain

### Data Synchronization
11. MovingBox must maintain local SwiftData storage regardless of sync service selection
12. All CRUD operations (Create, Read, Update, Delete) must be supported in both directions
13. New items created in MovingBox must automatically sync to HomeBox
14. New items created in HomeBox must automatically sync to MovingBox
15. Updates made in either system must propagate to the other
16. Deletions must be handled with proper conflict resolution

### Data Mapping
17. MovingBox `InventoryItem` objects must map to HomeBox `Item` objects with best-effort field matching
18. MovingBox `InventoryLocation` objects must map to HomeBox `Location` objects
19. MovingBox `InventoryLabel` objects must map to HomeBox `Label` objects
20. MovingBox `Home` objects must map to appropriate HomeBox equivalents
21. Photos attached to items must be uploaded to HomeBox and properly linked
22. Unmappable fields must be gracefully handled without causing sync failures

### Sync Scheduling and Performance
23. Sync must occur automatically on a regular schedule (every 5 minutes when active)
24. Manual sync triggers must be available through the Settings interface
25. Sync must be performed in the background without blocking the UI
26. Sync conflicts must be detected and resolved using last-write-wins strategy
27. Failed sync operations must be retried with exponential backoff

### Error Handling and User Feedback
28. Network connectivity issues must be handled gracefully with appropriate user feedback
29. Authentication failures must prompt users to re-authenticate
30. Sync errors must be logged and displayed to users in an understandable format
31. Users must be notified of successful sync operations and any issues that occur
32. Offline operation must continue to work with changes queued for sync when connectivity returns

## Non-Goals (Out of Scope)

1. Real-time collaborative editing (changes sync on schedule, not immediately)
2. Advanced conflict resolution beyond last-write-wins
3. Partial sync or selective item synchronization
4. Custom field mapping configuration by users
5. Support for multiple HomeBox instances simultaneously
6. Integration with HomeBox's user management or permissions system
7. Backup and restore functionality beyond standard sync
8. HomeBox server setup or configuration assistance
9. Support for HomeBox versions prior to the current stable release

## Design Considerations

- Follow MovingBox's existing design patterns for settings and configuration screens
- Provide clear visual indicators of sync status (syncing, synced, error states)
- Use standard iOS authentication patterns (ASWebAuthenticationSession when possible)
- Ensure sync status is visible but not intrusive to the primary user workflows
- Design for graceful degradation when HomeBox server is unavailable
- Maintain consistency with existing import/export functionality in the Settings

## Technical Considerations

### Architecture
- Create a new `SyncService` protocol with iCloud and HomeBox implementations
- Implement `HomeBoxSyncService` that manages API communication and data transformation
- Extend `SettingsManager` to include sync service selection and HomeBox configuration
- Create `HomeBoxAPIClient` based on the provided OpenAPI specification
- Implement data mapping layer between MovingBox and HomeBox models

### Authentication
- Use ASWebAuthenticationSession for OAuth flows when supported by HomeBox
- Fall back to username/password authentication stored securely in Keychain
- Implement token refresh logic for OAuth-based authentication
- Handle authentication expiration and re-authentication flows

### Data Synchronization
- Implement change tracking to identify items that need sync
- Create background task handling for sync operations
- Implement retry logic with exponential backoff for failed operations
- Add conflict detection and resolution mechanisms
- Ensure atomic operations where possible to maintain data consistency

### Photo Management
- Integrate with existing `OptimizedImageManager` for photo handling
- Implement photo upload to HomeBox with proper metadata
- Handle photo deletion and updates in sync operations
- Maintain photo associations during sync operations

### Testing and Migration
- Implement comprehensive unit tests for sync operations
- Create integration tests with mock HomeBox servers
- Design data migration strategies for users switching sync providers
- Ensure existing users are not affected by the new functionality

## Success Metrics

1. **User Adoption**: 15% of users enable HomeBox sync within 60 days of feature release
2. **Sync Reliability**: 99% of sync operations complete successfully
3. **Data Consistency**: 100% of items successfully sync between MovingBox and HomeBox in testing
4. **Authentication Success**: 95% of authentication attempts succeed on first try
5. **Performance**: Sync operations complete within 30 seconds for typical inventories (under 1000 items)
6. **User Satisfaction**: Positive feedback from beta users regarding ease of setup and reliability

## Open Questions

1. Should users be able to map custom fields between MovingBox and HomeBox?
2. How should we handle HomeBox-specific features that don't exist in MovingBox?
3. Should there be a migration tool to help users move from iCloud to HomeBox?
4. What happens to AI analysis history when syncing with HomeBox?
5. Should we support syncing only certain types of items or all data?
6. How should we handle HomeBox instances with different API versions?
7. Should there be any warnings or confirmations when switching sync providers?

## Dependencies

- HomeBox OpenAPI specification analysis
- ASWebAuthenticationSession framework (iOS 12+)
- Keychain Services for secure credential storage
- Background task handling for sync operations
- Network connectivity monitoring
- Existing OptimizedImageManager for photo handling