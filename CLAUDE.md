# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MovingBox is an iOS app that uses AI to help users manage home inventory by taking photos and automatically cataloging items. Built with SwiftUI and SwiftData, integrated with OpenAI Vision API, RevenueCat for subscriptions, and CloudKit for data sync.

## Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run UI tests  
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run snapshot tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# Generate App Store screenshots
fastlane screenshots
```

### Test Configuration
Use launch arguments for testing:
- `"Use-Test-Data"` - Load test data
- `"Mock-Data"` - Use mock data for snapshots
- `"Disable-Animations"` - Disable animations for tests
- `"Is-Pro"` - Enable pro features
- `"Skip-Onboarding"` - Skip onboarding flow

## Architecture

### Core Data Flow
- **SwiftData Models**: `InventoryItem`, `InventoryLocation`, `InventoryLabel`, `Home`, `InsurancePolicy`
- **Managers**: App-level state managers injected as `@EnvironmentObject`
  - `SettingsManager` - User preferences and settings
  - `OnboardingManager` - Welcome flow state
  - `ModelContainerManager` - SwiftData container lifecycle
  - `RevenueCatManager` - Subscription management
- **Router**: Navigation coordinator using `NavigationStack` and `NavigationPath`

### Key Services
- **DataManager**: CSV/ZIP export functionality (actor-based)
- **OpenAIService**: AI-powered image analysis
- **OptimizedImageManager**: Image storage and compression
- **TelemetryManager**: Analytics via TelemetryDeck
- **DefaultDataManager**: Test data population

### Navigation Pattern
Uses centralized `Router` with tab-based navigation and programmatic routing:
- Tab enum defines 5 main tabs (Dashboard, Locations, Add Item, All Items, Settings)
- Destination enum for deep navigation within tabs
- Each tab maintains its own `NavigationPath`

### Testing Infrastructure
- **Unit Tests**: Swift Testing framework with in-memory SwiftData containers
- **UI Tests**: XCTest with page object model pattern (Screen objects)
- **Snapshot Tests**: `swift-snapshot-testing` with light/dark mode variants
- **Test Plans**: Organized via `.xctestplan` files for different test suites

### Configuration System
- **AppConfig**: Centralized config with build-specific behavior
- **Environment Variables**: JWT_SECRET, REVENUE_CAT_API_KEY, SENTRY_DSN, TELEMETRY_DECK_APP_ID
- **Build Types**: Production vs Beta with different feature flags
- **Launch Arguments**: Extensive testing configuration options

### Image Management
- Migration pattern from SwiftData `@Attribute(.externalStorage)` to `OptimizedImageManager`
- Images stored outside Core Data for better performance
- Automatic migration with async/await pattern in model `init()`

## Important Patterns

### Model Migration
When models need image migration, implement `migrateImageIfNeeded()` async method and call from model initializer

### AI Integration  
OpenAI Vision API calls use structured responses with retry logic and error handling in `OpenAIService`

### Subscription Handling
RevenueCat integration with pro feature gating via `AppConfig.shared.isPro` and subscription status

### Error Handling
Comprehensive error tracking with Sentry integration and structured error types for each service
