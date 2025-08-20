# Process Task List Implementation

Implement a MovingBox feature by following an existing task list, adhering to development guidelines and task management protocols: $ARGUMENTS

## Implementation Protocol

### Task Execution Rules
1. **One Sub-Task at a Time**: Never start the next sub-task until you ask the user for permission and they say "yes" or "y"
2. **Sequential Processing**: Work through tasks in numbered order
3. **Wait for Approval**: Stop after each sub-task completion and ask for user approval to continue
4. **No Skipping**: Complete tasks in sequence - do not jump ahead

### Task Completion Protocol
When you finish a **sub-task**:
1. **Immediately mark it completed**: Change `[ ]` to `[x]` in the task list file
2. **Check parent task**: If ALL subtasks under a parent are now `[x]`, also mark the **parent task** as `[x]`
3. **Update file**: Save the updated task list to disk
4. **Request permission**: Ask user if you should proceed to the next sub-task

### Task List Maintenance
- **Keep task list current**: Update after every significant work completion
- **Add discovered tasks**: Insert new tasks as they emerge during implementation
- **Update "Relevant Files"**: Maintain accurate list of created/modified files with descriptions
- **Track progress**: Ensure completed work is properly marked

## MovingBox Implementation Guidelines

### Code Quality Standards
- **Follow existing patterns**: Use established SwiftUI, SwiftData, and service patterns
- **Maintain architecture**: Adhere to MVVM + Router architecture
- **Use conventions**: Follow naming conventions and file organization
- **Error handling**: Implement structured error types and proper error recovery

### Testing Requirements
- **Write tests first**: Follow TDD principles where applicable (use `/unittest` command)
- **Test coverage**: Ensure unit, integration, and UI test coverage
- **Run tests**: Execute tests after implementation to verify functionality
- **Snapshot tests**: Update visual regression tests when UI changes

### Development Workflow
1. **Read task list**: Identify the next incomplete sub-task
2. **Implement sub-task**: Follow MovingBox patterns and conventions
3. **Test implementation**: Run relevant tests to verify functionality
4. **Update task list**: Mark sub-task as completed and update relevant files
5. **Request approval**: Ask user permission to continue to next sub-task

## Implementation Process

### Phase 1: Setup and Validation
1. **Load task list**: Read the specified task list file
2. **Identify current position**: Find the next incomplete sub-task
3. **Validate prerequisites**: Ensure previous tasks are properly completed
4. **Confirm starting point**: Ask user if starting position is correct

### Phase 2: Sequential Implementation
For each sub-task:
1. **Announce task**: Tell user which sub-task you're starting
2. **Implement functionality**: Write code following MovingBox patterns
3. **Test implementation**: Run appropriate tests
4. **Update documentation**: Update inline comments and documentation as needed
5. **Mark completed**: Update task list file with completion
6. **Request approval**: Ask permission to proceed to next sub-task

### Phase 3: Integration and Validation
After completing task groups:
1. **Run full test suite**: Ensure no regressions
2. **Verify integration**: Test feature integration with existing app
3. **Update documentation**: Ensure all documentation is current
4. **Mark parent tasks**: Complete parent tasks when all sub-tasks are done

## Code Implementation Standards

### SwiftUI Implementation
```swift
// Follow existing view patterns
struct FeatureView: View {
    @StateObject private var viewModel = FeatureViewModel()
    @EnvironmentObject private var router: Router
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // Implementation following MovingBox patterns
    }
}

#Preview {
    FeatureView()
        .environmentObject(Router())
        .modelContainer(Previewer.container)
}
```

### Service Implementation
```swift
// Use actor pattern for thread safety
actor FeatureService: ObservableObject {
    private let logger = Logger(subsystem: "com.movingbox.app", category: "FeatureService")
    
    func performOperation() async throws -> Result {
        // Implementation with proper error handling
    }
}
```

### Error Handling
```swift
enum FeatureError: Error, LocalizedError {
    case invalidInput
    case networkFailure
    case dataCorruption
    
    var errorDescription: String? {
        // User-friendly error messages
    }
}
```

### Testing Implementation
```swift
@Test("Feature functionality works correctly")
func testFeatureFunctionality() async throws {
    // Arrange
    let testContainer = try createTestContainer()
    let service = FeatureService()
    
    // Act
    let result = try await service.performOperation()
    
    // Assert
    #expect(result.isSuccess)
}
```

## Task List Update Format

When updating the task list, follow this format:

```markdown
## Relevant Files

### Files Created
- `MovingBox/Views/Feature/FeatureView.swift` - Main SwiftUI view for the feature
- `MovingBox/Services/FeatureService.swift` - Business logic service implementation
- `MovingBoxTests/FeatureServiceTests.swift` - Unit tests for service functionality

### Files Modified
- `MovingBox/Services/Router.swift` - Added navigation destinations for feature
- `MovingBox/Views/Dashboard/DashboardView.swift` - Added navigation to new feature
- `changelog.md` - Documented new feature implementation

## Tasks

- [x] 1.0 **SwiftUI View Implementation**
  - [x] 1.1 Create FeatureView.swift in Views/Feature/ directory
  - [x] 1.2 Implement basic view structure following MovingBox patterns
  - [ ] 1.3 Add navigation integration with Router
  - [ ] 1.4 Implement state management with @StateObject and @EnvironmentObject
```

## User Interaction Protocol

### Before Starting Each Sub-Task
```
Starting sub-task [X.Y]: [Description]
This involves: [Brief explanation of what will be implemented]
Should I proceed? (yes/y to continue)
```

### After Completing Each Sub-Task
```
✅ Completed sub-task [X.Y]: [Description]
- Created/Modified: [List of files]
- Tests: [Test results if applicable]
- Updated task list: [Confirmation of task marking]

Ready to proceed to sub-task [X.Y+1]: [Next description]? (yes/y to continue)
```

### After Completing Parent Task
```
🎉 Completed parent task [X.0]: [Parent Description]
All sub-tasks completed successfully.

Ready to proceed to next parent task [X+1.0]: [Next parent description]? (yes/y to continue)
```

## Quality Assurance Checkpoints

### After Each Sub-Task
- [ ] Code follows MovingBox patterns and conventions
- [ ] Proper error handling is implemented
- [ ] Relevant tests are written and passing
- [ ] Documentation is updated as needed
- [ ] Task list is accurately updated

### After Each Parent Task
- [ ] All sub-tasks are marked complete
- [ ] Integration tests pass
- [ ] Feature works with existing app functionality
- [ ] No regressions introduced
- [ ] Ready for next development phase

## Build and Test Commands

Use these commands to verify implementation:

```bash
# Build project after implementation
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run UI tests for specific feature
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:MovingBoxUITests/[FeatureName]UITests

# Run snapshot tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

## Error Recovery Protocol

If implementation fails:
1. **Document the issue**: Note what went wrong in task list comments
2. **Revert if necessary**: Undo changes that caused failures
3. **Ask for guidance**: Request user input on how to proceed
4. **Update task list**: Mark problematic tasks with notes
5. **Continue safely**: Only proceed with user approval

## Success Criteria

Implementation is successful when:
- [ ] All tasks in the task list are marked complete
- [ ] All tests pass (unit, integration, UI, snapshot)
- [ ] Feature integrates properly with existing app
- [ ] Code follows MovingBox conventions and patterns
- [ ] Documentation is complete and accurate
- [ ] No regressions are introduced

## Final Steps

Upon completion:
1. **Run full test suite**: Ensure everything works correctly
2. **Update changelog**: Document the completed feature
3. **Review task list**: Confirm all tasks are properly marked
4. **Prepare for review**: Code is ready for team review
5. **Celebrate**: Feature implementation is complete! 🎉

Remember: The key to successful implementation is patience, attention to detail, and following the established patterns. Take it one sub-task at a time, and ask for approval before proceeding.