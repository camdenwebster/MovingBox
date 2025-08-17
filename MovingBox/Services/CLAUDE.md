# Services Directory - MovingBox

This directory contains business logic, utilities, and service classes that provide core functionality for the MovingBox app.

## Service Categories

### Core Services
- **OpenAIService**: AI-powered image analysis using OpenAI Vision API
- **OptimizedImageManager**: Efficient image storage and management
- **DataManager**: CSV/ZIP export functionality with actor-based concurrency
- **TelemetryManager**: Analytics and crash reporting via TelemetryDeck

### State Management
- **SettingsManager**: User preferences and app configuration
- **OnboardingManager**: Welcome flow state management
- **ModelContainerManager**: SwiftData container lifecycle management
- **RevenueCatManager**: Subscription and purchase management

### Utilities
- **Router**: Navigation coordination and deep linking
- **JWTManager**: Authentication token management
- **CurrencyFormatter**: Localized currency display
- **Logger**: Centralized logging infrastructure

### Development Support
- **DefaultDataManager**: Test data population
- **TestData**: Mock data for testing and development
- **Previewer**: SwiftUI preview support utilities

## Service Design Patterns

### Dependency Injection
- Use protocol-based dependency injection where appropriate
- Inject services as `@EnvironmentObject` at app level
- Consider service locator pattern for complex dependencies
- Avoid singleton pattern unless absolutely necessary

### Error Handling
- Define specific error types for each service
- Use `Result` types for operations that can fail
- Implement structured error reporting
- Provide meaningful error messages for users

### Async/Await Patterns
- Prefer structured concurrency over completion handlers
- Use `actor` for thread-safe state management
- Implement proper cancellation support
- Handle timeout scenarios appropriately

### Observable Objects
- Implement `ObservableObject` for state that affects UI
- Use `@Published` for properties that trigger UI updates
- Consider performance impact of frequent updates
- Implement proper `objectWillChange` triggering

## Service-Specific Guidelines

### OpenAIService
**Purpose**: AI-powered image analysis and item recognition

**Key Responsibilities:**
- Send images to OpenAI Vision API for analysis
- Parse structured responses into usable data
- Handle API rate limits and errors
- Manage retry logic for failed requests

**Implementation Notes:**
- Use structured prompts for consistent AI responses
- Implement exponential backoff for rate limiting
- Validate API responses before processing
- Consider image compression for large photos
- Handle network connectivity issues gracefully

### OptimizedImageManager
**Purpose**: Efficient storage and retrieval of user photos

**Key Responsibilities:**
- Store images with optimal compression
- Provide URLs for image access
- Handle image deletion and cleanup
- Migrate from SwiftData external storage

**Implementation Notes:**
- Use appropriate compression algorithms
- Implement lazy loading for performance
- Handle storage quota limits
- Provide thumbnail generation
- Support background image processing

### DataManager
**Purpose**: Export user data in various formats

**Key Responsibilities:**
- Generate CSV exports of inventory data
- Create ZIP archives with photos
- Handle large dataset exports efficiently
- Provide progress updates for long operations

**Implementation Notes:**
- Use `actor` for thread-safe operations
- Stream large datasets to avoid memory issues
- Implement cancellation support
- Provide meaningful progress feedback
- Handle file system errors appropriately

### SettingsManager
**Purpose**: Centralized user preferences and app configuration

**Key Responsibilities:**
- Store and retrieve user preferences
- Manage app-wide settings
- Handle settings synchronization
- Provide settings validation

**Implementation Notes:**
- Use `@AppStorage` for simple preferences
- Implement complex settings with UserDefaults
- Validate settings values appropriately
- Provide migration for settings schema changes
- Consider iCloud sync for settings

### Router
**Purpose**: Navigation coordination and deep linking

**Key Responsibilities:**
- Manage navigation state across tabs
- Handle deep link navigation
- Coordinate complex navigation flows
- Provide programmatic navigation API

**Implementation Notes:**
- Use `NavigationPath` for type-safe navigation
- Implement proper back stack management
- Handle tab switching and state preservation
- Support universal link handling
- Consider navigation analytics

### RevenueCatManager
**Purpose**: Subscription and in-app purchase management

**Key Responsibilities:**
- Handle subscription status
- Process purchase transactions
- Manage subscription lifecycle
- Provide purchase UI coordination

**Implementation Notes:**
- Follow RevenueCat best practices
- Handle subscription status changes
- Implement proper receipt validation
- Provide offline purchase support
- Handle subscription restoration

## Testing Strategies

### Unit Testing
- Mock external dependencies (APIs, file system)
- Test error handling scenarios thoroughly
- Use dependency injection for testability
- Create isolated test environments

### Integration Testing
- Test service interactions
- Verify API contract compliance
- Test background processing scenarios
- Validate data flow between services

### Performance Testing
- Monitor memory usage during operations
- Test with large datasets
- Measure operation completion times
- Verify proper resource cleanup

## Error Handling Patterns

### Service-Specific Errors
```swift
enum OpenAIServiceError: Error {
    case invalidAPIKey
    case rateLimitExceeded
    case invalidResponse
    case networkError(Error)
}
```

### Error Propagation
- Use `Result` types for fallible operations
- Implement error chaining for complex flows
- Provide recovery mechanisms where possible
- Log errors appropriately for debugging

### User-Facing Errors
- Translate service errors to user-friendly messages
- Provide actionable error recovery options
- Implement graceful degradation where possible
- Consider offline scenarios

## Performance Considerations

### Memory Management
- Use appropriate data structures for large datasets
- Implement proper cleanup for resources
- Consider weak references for delegates
- Monitor memory usage during operations

### Background Processing
- Use appropriate quality-of-service classes
- Implement proper queue management
- Handle app backgrounding/foregrounding
- Consider battery usage implications

### Caching Strategies
- Implement appropriate caching for expensive operations
- Use proper cache invalidation strategies
- Consider memory vs disk caching trade-offs
- Handle cache cleanup appropriately

## Security Best Practices

### API Security
- Store API keys securely (environment variables)
- Validate all external service responses
- Implement proper authentication
- Handle sensitive data appropriately

### Data Protection
- Encrypt sensitive data at rest
- Use secure communication protocols
- Implement proper access controls
- Handle user data deletion securely

### Privacy Compliance
- Implement data minimization principles
- Provide user consent mechanisms
- Support data export/deletion requests
- Handle telemetry data appropriately

## Integration Points

### SwiftData Integration
- Use proper context management
- Handle concurrent access appropriately
- Implement efficient queries
- Consider background processing needs

### CloudKit Integration
- Handle sync conflicts gracefully
- Implement offline-first patterns
- Consider quota limitations
- Handle user account changes

### Third-Party Services
- Implement proper error handling for external APIs
- Use appropriate retry strategies
- Handle service availability issues
- Monitor service health and performance

## Monitoring and Observability

### Logging
- Use structured logging for better debugging
- Log service operations and errors
- Avoid logging sensitive information
- Implement log rotation and cleanup

### Analytics
- Track key service metrics
- Monitor error rates and performance
- Implement proper event tracking
- Respect user privacy preferences

### Health Monitoring
- Implement service health checks
- Monitor resource usage
- Track operation success rates
- Provide diagnostic information

## Development Tools

### Debug Support
- Implement debug modes for services
- Provide detailed error information
- Support debug UI for service state
- Enable service operation tracing

### Testing Support
- Provide mock implementations
- Support test data injection
- Enable operation simulation
- Implement test helper utilities