# Build Project

Build the MovingBox iOS project with the specified configuration: $ARGUMENTS

## Build Commands

### Standard Build
Build the main MovingBox target for development:
```bash
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Clean Build
Perform a clean build to resolve build cache issues:
```bash
xcodebuild clean build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Release Build
Build for release configuration:
```bash
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Archive Build
Create an archive for App Store distribution:
```bash
xcodebuild archive -project MovingBox.xcodeproj -scheme MovingBox -archivePath MovingBox.xcarchive
```

## Build Process

### Pre-Build Checks
1. **Dependency Verification**: Ensure all Swift Package dependencies are resolved
2. **Configuration Review**: Verify build configuration and environment variables
3. **Simulator Status**: Confirm target simulator is available
4. **Workspace Clean**: Consider cleaning if previous builds failed

### Build Execution
1. **Start Build**: Execute appropriate build command
2. **Monitor Progress**: Watch for compilation errors and warnings
3. **Handle Errors**: Address any build failures immediately
4. **Verify Success**: Confirm successful build completion

### Post-Build Validation
1. **Binary Verification**: Ensure app binary was created successfully
2. **Resource Verification**: Check that assets and resources are included
3. **Size Analysis**: Monitor app size if building for distribution
4. **Quick Smoke Test**: Launch app briefly to verify basic functionality

## Build Configurations

### Development Build
- Debug configuration with full logging
- Simulator targeting for fast iteration
- Test data and mock configurations enabled
- Development certificates and provisioning

### Beta Build
- Release configuration with optimizations
- Device targeting for real-world testing
- Production-like configuration
- Beta provisioning profiles

### Production Build
- Release configuration fully optimized
- App Store distribution setup
- Production certificates and profiles
- All debugging and test features disabled

## Environment Variables

### Required Variables
Ensure these environment variables are set:
- `JWT_SECRET`: For authentication token management
- `REVENUE_CAT_API_KEY`: For subscription functionality
- `SENTRY_DSN`: For crash reporting
- `TELEMETRY_DECK_APP_ID`: For analytics

### Build-Specific Configuration
- Development: Use development/test API endpoints
- Beta: Use staging/beta API configurations
- Production: Use production API endpoints and keys

## Common Build Issues

### Dependency Problems
- **Swift Package Issues**: Clean and reload package dependencies
- **Version Conflicts**: Resolve package version conflicts
- **Cache Issues**: Clear DerivedData and package caches

### Configuration Issues
- **Missing Environment Variables**: Verify all required environment variables
- **Provisioning Profiles**: Ensure valid provisioning profiles for target
- **Certificates**: Verify code signing certificates are valid

### Code Issues
- **Compilation Errors**: Fix Swift compilation errors and warnings
- **Asset Issues**: Verify all referenced assets exist
- **Linker Errors**: Resolve missing framework or library dependencies

## Build Optimization

### Compilation Performance
- Use incremental builds when possible
- Clean build only when necessary
- Optimize build settings for development speed
- Consider using build caching when available

### App Size Optimization
- Review asset compression and optimization
- Remove unused code and resources
- Optimize image assets for app size
- Use appropriate Swift optimization levels

### Build Time Monitoring
- Track build times to identify performance regressions
- Profile compilation bottlenecks
- Optimize slow-compiling code when necessary
- Consider modularization for large projects

## Platform-Specific Builds

### iOS Simulator
- Fastest build and test cycle
- Full debugging capabilities
- Limited hardware feature testing
- x86_64/arm64 architecture support

### iOS Device
- Real-world performance testing
- Full hardware feature access
- Requires valid provisioning
- arm64 architecture targeting

### Universal Build
- Support multiple architectures
- Larger binary size
- Maximum device compatibility
- Required for App Store distribution

## Build Validation

### Automated Checks
- Compile without warnings
- Pass static analysis
- Verify resource inclusion
- Check code signing validity

### Manual Verification
- Launch app successfully
- Verify core functionality works
- Check UI layout and appearance
- Test key user flows briefly

### Performance Validation
- App launch time
- Memory usage at startup
- Initial UI responsiveness
- Background processing behavior

## Troubleshooting

### Build Failures
1. **Check Error Messages**: Read compilation errors carefully
2. **Clean Environment**: Clean build folders and caches
3. **Verify Dependencies**: Ensure all dependencies are available
4. **Check Configuration**: Verify build settings and environment

### Performance Issues
1. **Monitor Build Times**: Track unusually slow builds
2. **Check Resource Usage**: Monitor CPU and memory during builds
3. **Identify Bottlenecks**: Profile slow compilation units
4. **Optimize Settings**: Adjust build settings for performance

Remember:
- Always build successfully before committing code
- Address warnings as well as errors
- Test builds on both simulator and device when possible
- Monitor build performance and optimize when necessary
- Keep build configurations consistent across environments