# Run Tests

Execute the appropriate test suite for MovingBox based on the specified test type: $ARGUMENTS

## Test Suite Options

### Unit Tests (Default)
Run the core unit test suite with business logic and model tests:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### UI Tests
Execute user interface and interaction tests:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Snapshot Tests
Run visual regression tests for UI components:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

### All Tests
Execute the complete test suite:
```bash
# Run unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run UI tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run snapshot tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

## Test Execution Process

### Pre-Test Setup
1. **Simulator Status**: Verify iPhone simulator is available and ready
2. **Build Status**: Ensure project builds successfully before running tests
3. **Test Data**: Confirm test data and mock configurations are in place
4. **Environment**: Set appropriate test environment variables if needed

### Test Execution
1. **Clean Build**: Consider clean build if tests were previously failing
2. **Run Tests**: Execute the appropriate test command
3. **Monitor Output**: Watch for test failures and performance issues
4. **Collect Results**: Gather test results and any generated artifacts

### Post-Test Analysis
1. **Result Review**: Analyze test failures and success rates
2. **Performance Metrics**: Check test execution times
3. **Coverage Analysis**: Review code coverage if applicable
4. **Artifact Collection**: Save screenshots, logs, or other test outputs

## Test Configuration Options

### Launch Arguments for Testing
Configure test behavior using launch arguments:
- `"Use-Test-Data"` - Load predefined test data
- `"Mock-Data"` - Use mock data for consistent testing
- `"Disable-Animations"` - Speed up UI tests by disabling animations
- `"Is-Pro"` - Test pro features and subscription behavior
- `"Skip-Onboarding"` - Bypass onboarding flow for faster test setup

### Device and OS Configuration
- **Primary Device**: iPhone 16 Pro for unit and UI tests
- **Snapshot Device**: iPhone 14 Pro for visual consistency
- **iOS Version**: Use latest available iOS simulator version
- **Orientation**: Test in portrait mode by default

## Specific Test Scenarios

### Feature Testing
When testing specific features, include:
- Core functionality verification
- Error handling and edge cases
- Performance under load
- Integration with external services

### Regression Testing
For bug fixes and updates:
- Run full test suite to catch regressions
- Focus on areas related to recent changes
- Verify fix effectiveness
- Test edge cases related to the bug

### Performance Testing
For performance-sensitive features:
- Monitor memory usage during tests
- Check execution times for critical operations
- Test with large datasets when applicable
- Verify background processing behavior

## Test Failure Handling

### Common Failure Patterns
- **Timing Issues**: UI tests failing due to animation timing
- **Data Dependencies**: Tests failing due to missing test data
- **Simulator State**: Tests affected by simulator configuration
- **Network Dependencies**: Tests failing due to external service calls

### Debugging Failed Tests
1. **Examine Test Logs**: Review detailed test output and error messages
2. **Check Screenshots**: For UI tests, review captured screenshots
3. **Verify Environment**: Confirm test environment is properly configured
4. **Isolate Failures**: Run individual failing tests to isolate issues

### Test Maintenance
- Update tests when functionality changes
- Maintain test data and mock configurations
- Keep snapshot references current
- Review and refactor flaky tests

## Test Reports and Artifacts

### Generated Artifacts
- Test result summaries and detailed logs
- UI test screenshots and recordings
- Snapshot test reference images
- Code coverage reports (if configured)

### Result Analysis
- Identify patterns in test failures
- Monitor test execution performance
- Track test reliability over time
- Report significant test issues

## Continuous Integration

### Automated Testing
When running in CI environments:
- Ensure simulators are properly configured
- Set appropriate timeouts for test execution
- Handle test artifacts and reports
- Configure notifications for test failures

### Test Strategy
- Run unit tests for every commit
- Execute UI tests for major changes
- Update snapshots when UI changes
- Perform full test suite before releases

Remember:
- Always run tests before committing code changes
- Address test failures promptly
- Keep tests fast and reliable
- Use appropriate test configurations for different scenarios
- Monitor test performance and reliability over time