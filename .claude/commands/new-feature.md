# New Feature Implementation

Please analyze the MovingBox codebase and create a comprehensive plan to implement the following iOS feature: $ARGUMENTS

Follow the "Explore, plan, code, test, commit" workflow specifically for iOS development:

## Analysis Phase
1. **Explore Dependencies**: Examine existing SwiftUI views, SwiftData models, and service integrations
2. **Architecture Review**: Identify how this feature fits into the current MVVM + Router architecture
3. **Integration Points**: Consider impacts on:
   - OpenAI Vision API integration
   - RevenueCat subscription gating
   - SwiftData models and relationships
   - CloudKit sync compatibility
   - TelemetryDeck analytics

## Planning Phase
Create a detailed implementation plan addressing:

### UI Implementation
- SwiftUI view architecture and composition
- Navigation integration with Router
- State management using appropriate property wrappers
- Accessibility considerations
- Light/dark mode support

### Data Layer
- SwiftData model changes (if needed)
- Migration strategy for schema changes
- Service layer modifications
- Image handling via OptimizedImageManager

### Testing Strategy
- Unit tests for business logic
- UI tests for critical user flows
- Snapshot tests for visual consistency
- Integration tests for service interactions

### Performance Considerations
- Memory usage during operations
- Image processing efficiency
- Background processing requirements
- User experience during async operations

## Implementation Requirements
- Follow existing code conventions and patterns
- Use dependency injection via @EnvironmentObject
- Implement proper error handling with structured error types
- Consider subscription feature gating where appropriate
- Include comprehensive logging for debugging

**DO NOT write any code until I approve the plan.** Use "think hard" to thoroughly evaluate implementation alternatives and potential challenges.

Remember to consider:
- iOS Human Interface Guidelines compliance
- App Store review guidelines
- Privacy and security implications
- Backwards compatibility
- Localization support (if applicable)