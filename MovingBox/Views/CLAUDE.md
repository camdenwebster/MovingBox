# Views Directory - MovingBox

This directory contains all SwiftUI views for the MovingBox iOS app, organized by feature area.

## Directory Structure

- **Items/**: Inventory item management views (add, edit, list, detail)
- **Locations/**: Location and room management views
- **Onboarding/**: Welcome flow and first-time user experience
- **Other/**: Camera functionality and miscellaneous views
- **Settings/**: App settings and subscription management
- **Shared/**: Reusable UI components used across features

## SwiftUI Best Practices

### View Architecture
- **Single Responsibility**: Each view should have one clear purpose
- **Composition**: Prefer small, composable views over large monolithic ones
- **State Management**: Use appropriate property wrappers:
  - `@State`: Local view state
  - `@StateObject`: Owned observable objects
  - `@ObservedObject`: Injected observable objects
  - `@EnvironmentObject`: App-wide managers (SettingsManager, Router, etc.)

### Data Flow Patterns
- **Unidirectional Data Flow**: Data flows down, events flow up
- **Environment Objects**: Access shared state via `@EnvironmentObject`
  - `SettingsManager`: User preferences and app settings
  - `Router`: Navigation state and routing
  - `OnboardingManager`: Welcome flow state
  - `RevenueCatManager`: Subscription status
- **Model Context**: Access SwiftData via `@Environment(\.modelContext)`

### Navigation
- Use centralized `Router` for navigation between screens
- Leverage `NavigationStack` and `NavigationPath` for deep linking
- Tab-based navigation with programmatic routing within tabs
- Pass data through navigation using proper Swift types

### View Lifecycle
- **onAppear/onDisappear**: Use for setup/cleanup, avoid heavy operations
- **task**: Prefer for async operations over onAppear
- **background**: Handle app state changes appropriately

## UI Component Guidelines

### Layout and Spacing
- Use system spacing (`spacing: 16`) and padding for consistency
- Leverage `Spacer()` for flexible layouts
- Use `GeometryReader` sparingly, prefer intrinsic content sizing
- Follow iOS Human Interface Guidelines for spacing and sizing

### Colors and Theming
- Use semantic colors that adapt to light/dark mode
- Leverage `ColorExtension.swift` for custom color definitions
- Test all UI in both light and dark appearances
- Use system colors when appropriate for accessibility

### Typography
- Use system font sizes and weights for consistency
- Implement Dynamic Type support for accessibility
- Use appropriate text styles (.title, .headline, .body, etc.)

### Accessibility
- Provide meaningful accessibility labels and hints
- Support VoiceOver navigation
- Ensure minimum touch target sizes (44x44 points)
- Test with accessibility features enabled

### Animation and Transitions
- Use built-in transitions when possible
- Keep animations subtle and purposeful
- Disable animations in test environment
- Consider reduced motion accessibility settings

## Feature-Specific Guidelines

### Camera Views
- Handle camera permissions gracefully
- Provide fallback for simulator testing
- Implement proper image capture and processing flows
- Use `OptimizedImageManager` for image storage

### List Views
- Implement proper SwiftData queries with fetch descriptors
- Use lazy loading for large datasets
- Handle empty states gracefully
- Provide appropriate delete and edit actions

### Forms and Input
- Use proper form validation patterns
- Provide clear error messaging
- Handle keyboard avoidance automatically
- Implement proper focus management

### Image Display
- Use `AsyncImage` for remote images
- Implement proper loading and error states
- Consider image sizing and compression
- Support pinch-to-zoom where appropriate

## Testing Considerations

### Preview Support
- Provide meaningful previews for all views
- Use test data from `TestData.swift`
- Include multiple preview variants (light/dark, different data states)
- Use `Previewer.swift` for consistent preview setup

### Snapshot Testing
- Ensure views are snapshot test compatible
- Handle dynamic content appropriately
- Test in multiple device sizes and orientations
- Use launch arguments for consistent test states

### UI Testing
- Implement accessibility identifiers for UI testing
- Follow page object pattern for test organization
- Handle animation states in tests
- Use appropriate test data scenarios

## Performance Best Practices

### View Updates
- Minimize unnecessary view recomputations
- Use `@StateObject` vs `@ObservedObject` appropriately
- Consider view update frequency for real-time features

### Image Handling
- Implement lazy loading for image galleries
- Use appropriate image resolutions
- Consider memory usage for large photo collections
- Leverage `OptimizedImageManager` for efficient storage

### Large Lists
- Use lazy loading patterns
- Implement proper pagination
- Consider virtual scrolling for very large datasets
- Monitor memory usage during scrolling

## Common Patterns

### Error Handling
- Display user-friendly error messages
- Provide retry mechanisms where appropriate
- Handle network connectivity issues gracefully
- Use consistent error presentation patterns

### Loading States
- Show loading indicators for async operations
- Provide skeleton screens for better UX
- Handle timeout scenarios appropriately
- Maintain UI responsiveness during operations

### State Persistence
- Save form state when appropriate
- Handle app backgrounding/foregrounding
- Restore scroll position when needed
- Use proper data binding for persistent state

## Integration Points

### Router Integration
- Use `Router` for all navigation between screens
- Pass data through navigation parameters
- Handle deep linking scenarios
- Maintain proper navigation stack state

### Service Integration
- Access services through environment objects
- Handle service errors appropriately
- Implement proper loading states for service calls
- Consider offline scenarios

### Model Integration
- Use SwiftData queries efficiently
- Handle model updates reactively
- Implement proper delete confirmations
- Consider data validation at the view layer