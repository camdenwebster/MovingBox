# Review Pull Request

Review the pull request specified by: $ARGUMENTS

Use the GitHub CLI to fetch PR details and analyze the changes for code quality, adherence to MovingBox standards, and potential issues.

## Review Process

### 1. Fetch PR Information
```bash
# Get PR details
gh pr view $PR_NUMBER

# Get PR diff
gh pr diff $PR_NUMBER

# List PR files
gh pr view $PR_NUMBER --json files
```

### 2. Initial Assessment
- **PR Scope**: Assess if the PR has appropriate scope (not too large)
- **Description Quality**: Verify PR description explains changes and rationale
- **Breaking Changes**: Identify any breaking changes or API modifications
- **Test Coverage**: Check if appropriate tests are included

## Code Quality Review

### iOS-Specific Standards
- **Swift Conventions**: Verify camelCase for variables, PascalCase for types
- **SwiftUI Patterns**: Check proper use of @State, @StateObject, @ObservedObject
- **Architecture Compliance**: Ensure changes follow MVVM + Router pattern
- **Protocol Usage**: Verify protocol-oriented programming where appropriate

### MovingBox Patterns
- **Service Integration**: Check proper use of EnvironmentObject managers
- **Navigation**: Verify Router usage for navigation between screens
- **Data Management**: Ensure proper SwiftData patterns and relationships
- **Error Handling**: Check for consistent error handling patterns

### Performance Considerations
- **Memory Management**: Look for potential retain cycles or memory leaks
- **Image Handling**: Verify OptimizedImageManager usage for images
- **Async Patterns**: Check proper async/await and actor usage
- **Background Processing**: Ensure appropriate background processing patterns

## Security and Privacy Review

### Data Protection
- **Sensitive Data**: Ensure no sensitive information is logged or exposed
- **API Keys**: Verify no hardcoded API keys or secrets
- **User Privacy**: Check compliance with privacy requirements
- **Data Validation**: Verify proper input validation and sanitization

### iOS Security
- **Keychain Usage**: Check secure storage for sensitive data
- **Network Security**: Verify HTTPS usage and certificate validation
- **Permissions**: Ensure appropriate permission requests and handling
- **Secure Coding**: Look for common security vulnerabilities

## Functional Review

### Feature Implementation
- **Requirements Fulfillment**: Verify PR addresses stated requirements
- **Edge Cases**: Check handling of edge cases and error scenarios
- **User Experience**: Assess impact on user experience and workflow
- **Accessibility**: Verify accessibility features are maintained/improved

### Integration Points
- **AI Integration**: Check OpenAI service usage and error handling
- **Subscription Logic**: Verify RevenueCat integration and pro feature gating
- **Analytics**: Ensure proper TelemetryDeck event tracking
- **Data Sync**: Check CloudKit compatibility if applicable

## Testing Review

### Test Coverage
- **Unit Tests**: Verify appropriate unit test coverage for new functionality
- **UI Tests**: Check if UI changes include corresponding UI tests
- **Integration Tests**: Ensure service integrations are properly tested
- **Snapshot Tests**: Verify visual changes include snapshot test updates

### Test Quality
- **Test Structure**: Check for proper test organization and naming
- **Mock Usage**: Verify appropriate mocking of external dependencies
- **Test Data**: Ensure tests use proper test data and cleanup
- **Edge Case Testing**: Check coverage of edge cases and error scenarios

## Documentation Review

### Code Documentation
- **Inline Comments**: Check for appropriate code comments where needed
- **API Documentation**: Verify public API changes are documented
- **Complex Logic**: Ensure complex algorithms or business logic are explained
- **TODO/FIXME**: Check for and assess any TODO or FIXME comments

### User-Facing Documentation
- **README Updates**: Check if README needs updates for new features
- **Changelog**: Verify changelog is updated if applicable
- **Migration Guides**: Check if breaking changes include migration guidance
- **Feature Documentation**: Ensure new features are documented appropriately

## Review Checklist

### Code Quality
- [ ] Follows Swift and SwiftUI best practices
- [ ] Adheres to MovingBox architecture patterns
- [ ] Proper error handling and edge case coverage
- [ ] No code duplication or violations of DRY principle
- [ ] Appropriate use of access control (private, internal, public)

### Performance
- [ ] No obvious performance regressions
- [ ] Proper memory management patterns
- [ ] Efficient algorithms and data structures
- [ ] Appropriate async/await usage

### Security
- [ ] No sensitive data exposure
- [ ] Proper input validation
- [ ] Secure communication patterns
- [ ] Privacy compliance maintained

### Testing
- [ ] Adequate test coverage for new functionality
- [ ] Tests follow established patterns
- [ ] All tests pass successfully
- [ ] Edge cases are covered

### Documentation
- [ ] Code is well-documented where necessary
- [ ] Public APIs are documented
- [ ] User-facing changes are documented
- [ ] Breaking changes are clearly noted

## Review Feedback Guidelines

### Constructive Feedback
- **Be Specific**: Provide specific examples and suggestions
- **Explain Rationale**: Explain why changes are needed
- **Offer Solutions**: Suggest concrete improvements
- **Acknowledge Good Work**: Highlight positive aspects of the PR

### Severity Levels
- **Critical**: Security issues, data corruption, crashes
- **Major**: Performance issues, architectural violations
- **Minor**: Style issues, documentation improvements
- **Nitpick**: Subjective preferences, minor optimizations

### Comment Types
- **Required Changes**: Issues that must be addressed before merge
- **Suggestions**: Improvements that would be beneficial
- **Questions**: Requests for clarification or explanation
- **Praise**: Recognition of good implementation or design

## Final Assessment

### Merge Readiness
- All critical and major issues are resolved
- Tests pass successfully
- Documentation is adequate
- Code follows established patterns and conventions
- Security and privacy requirements are met

### Follow-up Actions
- Identify any technical debt introduced
- Note areas for future improvement
- Suggest refactoring opportunities
- Plan for monitoring after deployment

Remember:
- **Focus on the code, not the person** - keep feedback objective
- **Prioritize security and correctness** over style preferences
- **Consider maintainability** - code will be read more than written
- **Respect the author's effort** while maintaining quality standards
- **Use the review as a learning opportunity** for the entire team