# Create Implementation Tasks

Generate a detailed, step-by-step task list for implementing a MovingBox feature based on an existing PRD and feature plan: $ARGUMENTS

## Goal

Create actionable implementation tasks that guide a developer through building the feature, following MovingBox's architecture patterns and development conventions.

## Process Overview

### 1. Input Analysis
Analyze the provided inputs to understand implementation scope:
- **PRD Reference**: Functional requirements and user stories
- **Feature Plan**: Technical architecture and integration strategy (from `/feature` command)
- **MovingBox Context**: Existing codebase patterns and conventions

### 2. Phase 1: Generate Parent Tasks
Create 5-7 high-level implementation areas based on MovingBox's typical feature structure:
- SwiftUI View Implementation
- SwiftData Model Changes
- Service Layer Integration  
- Navigation and Routing
- Testing Implementation
- Documentation Updates

Present these to the user and ask: **"I have generated the high-level tasks based on the PRD and feature plan. Ready to generate the detailed sub-tasks? Respond with 'Go' to proceed."**

### 3. Wait for User Confirmation
Pause and wait for user to respond with "Go" before proceeding to detailed sub-tasks.

### 4. Phase 2: Generate Detailed Sub-Tasks
Break down each parent task into specific, actionable sub-tasks following MovingBox patterns:
- File creation with proper naming conventions
- SwiftUI view composition and state management
- Service integration with proper error handling
- Test implementation across unit, integration, and UI levels
- Documentation updates

### 5. Identify Relevant Files
List specific files that will need creation or modification, following MovingBox's directory structure.

### 6. Save Task List
Save as `tasks-[feature-name].md` in the project root directory.

## MovingBox-Specific Task Categories

### SwiftUI Implementation Tasks
- View creation in appropriate feature directory (`Views/[Feature]/`)
- ViewModel implementation with `@Observable` pattern
- Environment object integration (`Router`, `SettingsManager`, etc.)
- Accessibility implementation
- Light/dark mode support

### Data Layer Tasks
- SwiftData model modifications or additions
- Migration strategy implementation
- Model relationship updates
- Data validation logic

### Service Integration Tasks
- Service protocol definition
- Service implementation with actor pattern
- Error handling with structured error types
- Integration with existing services (OpenAI, OptimizedImageManager, etc.)

### Navigation Tasks
- Router destination additions
- Deep linking support
- Tab navigation integration
- Navigation flow testing

### Testing Tasks
- Unit tests for business logic
- Integration tests for service interactions
- UI tests for user workflows
- Snapshot tests for visual consistency

## Output Format

```markdown
# Implementation Tasks: [Feature Name]

Based on PRD: `prd-[feature-name].md`
Feature Plan: `plan.md` (or reference to feature planning session)

## Relevant Files

### New Files to Create
- `MovingBox/Views/[Feature]/[FeatureName]View.swift` - Main SwiftUI view for the feature
- `MovingBox/Views/[Feature]/[FeatureName]ViewModel.swift` - Observable view model for state management
- `MovingBox/Services/[FeatureName]Service.swift` - Business logic service
- `MovingBox/Models/[ModelName].swift` - New SwiftData model (if needed)

### Files to Modify
- `MovingBox/Services/Router.swift` - Add navigation destinations
- `MovingBox/Views/[ExistingView].swift` - Integration points with existing views
- `MovingBox/Configuration/AppConfig.swift` - Feature flags or configuration (if needed)

### Test Files to Create
- `MovingBoxTests/[FeatureName]ServiceTests.swift` - Unit tests for service logic
- `MovingBoxTests/[FeatureName]ViewModelTests.swift` - ViewModel behavior tests
- `MovingBoxUITests/[FeatureName]UITests.swift` - End-to-end user flow tests
- `MovingBoxTests/SnapshotTests.swift` - Add snapshot test cases

### Documentation Updates
- `CLAUDE.md` - Update with new feature patterns (if applicable)
- `changelog.md` - Document the new feature
- `plan.md` - Update with implementation notes

## Implementation Tasks

- [ ] 1.0 **SwiftUI View Implementation**
  - [ ] 1.1 Create `[FeatureName]View.swift` in `Views/[Feature]/` directory
  - [ ] 1.2 Implement basic view structure following MovingBox patterns
  - [ ] 1.3 Add navigation integration with Router
  - [ ] 1.4 Implement state management with `@StateObject` and `@EnvironmentObject`
  - [ ] 1.5 Add accessibility identifiers and labels
  - [ ] 1.6 Test light and dark mode appearance
  - [ ] 1.7 Add SwiftUI previews with test data

- [ ] 2.0 **Data Layer Implementation**
  - [ ] 2.1 Create or modify SwiftData models as needed
  - [ ] 2.2 Implement model relationships and constraints
  - [ ] 2.3 Add data validation logic
  - [ ] 2.4 Create migration strategy if schema changes required
  - [ ] 2.5 Test model persistence and retrieval
  - [ ] 2.6 Verify CloudKit sync compatibility

- [ ] 3.0 **Service Layer Integration**
  - [ ] 3.1 Create service protocol defining interface
  - [ ] 3.2 Implement service class with actor pattern (if concurrent access needed)
  - [ ] 3.3 Add structured error types and handling
  - [ ] 3.4 Integrate with existing services (OpenAI, OptimizedImageManager, etc.)
  - [ ] 3.5 Implement proper logging with structured data
  - [ ] 3.6 Add TelemetryDeck event tracking

- [ ] 4.0 **Navigation and Routing**
  - [ ] 4.1 Add new destinations to Router enum
  - [ ] 4.2 Implement navigation methods in Router
  - [ ] 4.3 Add deep linking support (if applicable)
  - [ ] 4.4 Test navigation flows from all entry points
  - [ ] 4.5 Verify tab navigation integration
  - [ ] 4.6 Handle navigation edge cases and error states

- [ ] 5.0 **Testing Implementation**
  - [ ] 5.1 Create unit tests for service logic
  - [ ] 5.2 Create integration tests for service interactions
  - [ ] 5.3 Add UI tests for critical user workflows
  - [ ] 5.4 Create snapshot tests for visual consistency
  - [ ] 5.5 Test error handling scenarios
  - [ ] 5.6 Verify performance with large datasets (if applicable)

- [ ] 6.0 **Integration and Polish**
  - [ ] 6.1 Integrate with subscription logic (free vs pro features)
  - [ ] 6.2 Add feature flags or configuration as needed
  - [ ] 6.3 Implement proper error messaging for users
  - [ ] 6.4 Add loading states and progress indicators
  - [ ] 6.5 Verify accessibility compliance
  - [ ] 6.6 Test on different device sizes and orientations

- [ ] 7.0 **Documentation and Deployment**
  - [ ] 7.1 Update relevant CLAUDE.md files with new patterns
  - [ ] 7.2 Add feature to changelog.md
  - [ ] 7.3 Update inline code documentation
  - [ ] 7.4 Create or update user-facing documentation
  - [ ] 7.5 Prepare for code review
  - [ ] 7.6 Plan rollout strategy and monitoring

## Testing Commands

Run these commands to verify implementation:

```bash
# Build project
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run UI tests for this feature
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:MovingBoxUITests/[FeatureName]UITests

# Run snapshot tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

## Implementation Notes

### Code Style Guidelines
- Follow existing SwiftUI patterns in the codebase
- Use `@Observable` for ViewModels
- Implement proper error handling with structured error types
- Add comprehensive logging for debugging
- Use dependency injection through `@EnvironmentObject`

### Performance Considerations
- Optimize image handling through OptimizedImageManager
- Consider memory usage for large datasets
- Implement proper async/await patterns
- Use actors for thread-safe operations

### Quality Assurance
- Test on both iPhone and iPad
- Verify accessibility features
- Test with different data states (empty, populated, error)
- Ensure proper error recovery mechanisms

## Success Criteria

The feature is complete when:
- [ ] All tasks are checked off and tested
- [ ] Code passes all unit, integration, and UI tests
- [ ] Feature works correctly on iPhone and iPad
- [ ] Accessibility requirements are met
- [ ] Code review is approved
- [ ] Documentation is updated
- [ ] Feature is ready for deployment
```

## Usage Instructions

1. **After PRD and Feature Planning**: Use this command when you have both a PRD and technical feature plan
2. **Reference Both Documents**: Provide the PRD file and any feature planning output
3. **Two-Phase Generation**: Review high-level tasks before detailed breakdown
4. **Implementation Ready**: Tasks should be detailed enough for direct implementation

## Integration with Existing Commands

- **Input from** `/create-prd`: Business requirements and user stories
- **Input from** `/feature`: Technical architecture and integration strategy  
- **Output to**: Direct implementation by developers
- **Complemented by**: `/unittest`, `/build`, `/test` commands during implementation

This creates a complete workflow from business requirements to deployed feature.