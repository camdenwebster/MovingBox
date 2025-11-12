# MovingBox Agent Guidelines

## Project Overview
MovingBox is an iOS app that uses AI to help users manage home inventory by taking photos and automatically cataloging items. Built with SwiftUI and SwiftData, integrated with OpenAI Vision API, RevenueCat for subscriptions, and CloudKit for data sync.

## Build/Test Commands
- **Build**: `xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- **Unit Tests**: `xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- **UI Tests**: `xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- **Snapshot Tests**: `xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'`
- **Single Test**: `xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -only-testing:MovingBoxTests/CurrencyFormatterTests/testFormatCurrency`
- **Screenshots**: `fastlane screenshots`

## Test Configuration
Use launch arguments for testing:
- `"Use-Test-Data"` - Load test data
- `"Mock-Data"` - Use mock data for snapshots
- `"Disable-Animations"` - Disable animations for tests
- `"Is-Pro"` - Enable pro features
- `"Skip-Onboarding"` - Skip onboarding flow

## Code Style Guidelines
- **Imports**: Group logically (Foundation, SwiftUI, then third-party)
- **Naming**: camelCase for vars/functions, PascalCase for types/protocols
- **Access**: Prefer `private`/`fileprivate`, explicit `public` for interfaces
- **SwiftUI**: `@StateObject` (owned), `@ObservedObject` (injected), `@EnvironmentObject` (app-wide)
- **Async**: Prefer structured concurrency with `async/await`, use `actor` for thread-safety
- **File Org**: Models in `/Models/`, Views by feature in `/Views/`, Services in `/Services/`
- **Error Handling**: Structured error types per service, comprehensive logging
- **Testing**: Swift Testing framework with `@Test`/`@Suite`, descriptive test names

## TelemetryDeck Signal Naming
Use hierarchical dot notation following TelemetryDeck best practices:
- **Format**: `Category.Subcategory.action` (UpperCamelCase for categories, lowerCamelCase for actions)
- **Actions**: Present tense verbs (e.g., `created`, `deleted`, `toggled`, `selected`)
- **Events**: Past tense or passive (e.g., `started`, `completed`, `shown`, `appeared`)
- **Depth**: Keep hierarchy 2-3 levels max for maintainability

### Current Signal Categories
- `Inventory.itemCreated`, `Inventory.itemDeleted`
- `Inventory.Analysis.cameraUsed`, `Inventory.Analysis.photoUsed`
- `AIAnalysis.started`, `AIAnalysis.completed`, `AIAnalysis.tokenUsage`, `AIAnalysis.retryAttempt`
- `Settings.Location.created`, `Settings.Location.deleted`
- `Settings.Label.created`, `Settings.Label.deleted`
- `Settings.Analysis.highQualityToggled`
- `Onboarding.Survey.usageSelected`, `Onboarding.Survey.skipped`
- `Navigation.tabSelected`
- `AppStore.reviewRequested`

### Guidelines
- Group related signals under common namespace (e.g., all AI analysis under `AIAnalysis.*`)
- Use parameters for variations (e.g., `tab` parameter) rather than separate signal types
- Maintain consistency: don't rename when features move unless necessary
- Reference: https://telemetrydeck.com/docs/articles/signal-type-naming/

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

### Configuration System
- **AppConfig**: Centralized config with build-specific behavior
- **Environment Variables**: JWT_SECRET, REVENUE_CAT_API_KEY, SENTRY_DSN, TELEMETRY_DECK_APP_ID
- **Build Types**: Production vs Beta with different feature flags
- **Launch Arguments**: Extensive testing configuration options

## Important Patterns

### Model Migration
When models need image migration, implement `migrateImageIfNeeded()` async method and call from model initializer

### AI Integration
OpenAI Vision API calls use structured responses with retry logic and error handling in `OpenAIService`

### Subscription Handling
RevenueCat integration with pro feature gating via `AppConfig.shared.isPro` and subscription status

### Image Management
- Migration pattern from SwiftData `@Attribute(.externalStorage)` to `OptimizedImageManager`
- Images stored outside Core Data for better performance
- Automatic migration with async/await pattern in model `init()`

## Integration Points

### Third-Party Services
- **OpenAI Vision API**: Handle rate limits, implement retry logic, structure prompts for consistency
- **RevenueCat**: Gate pro features appropriately, handle subscription state changes
- **TelemetryDeck**: Track key user actions, respect privacy settings
- **CloudKit**: Handle sync conflicts, implement offline-first patterns

## Known Issues & Gotchas

### SwiftData Migration
- Image migration from `@Attribute(.externalStorage)` requires careful async handling
- Test with various data states during migration development
- Use `ModelContainerManager` for consistent container lifecycle

### OpenAI API
- Vision API has rate limits, implement exponential backoff
- Large images may need compression via `OptimizedImageManager`
- Structure prompts consistently for reliable parsing

### UI Testing
- Disable animations in test environment for consistency
- Use appropriate launch arguments for test data scenarios
- Screenshot tests require consistent simulator state

## Performance Considerations

### Image Handling
- Use `OptimizedImageManager` for all image storage
- Implement lazy loading for large photo collections
- Consider image compression for network operations

### SwiftData Optimization
- Use appropriate fetch descriptors and predicates
- Implement pagination for large datasets
- Consider background contexts for heavy operations

## Security & Privacy

### Data Protection
- Never log sensitive user data or API keys
- Use secure storage for authentication tokens
- Implement proper data validation and sanitization

### API Security
- Store API keys in environment variables or secure configuration
- Validate all OpenAI API responses
- Implement proper error handling without exposing internal state

### User Privacy
- Respect user consent for telemetry
- Implement proper data export/deletion capabilities
- Follow App Store privacy guidelines