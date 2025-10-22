# Sentry Integration

## Overview
MovingBox integrates Sentry (v8.54.0) for error tracking and performance monitoring. Sentry automatically captures crashes, errors, and performance data to help identify and fix issues in production.

## Configuration

### Environment Setup
Sentry DSN is configured in `MovingBox/Configuration/Base.xcconfig`:
```
SENTRY_DSN = <your-sentry-dsn>
```

The DSN is read by `AppConfig.sentryDsn` and used to initialize Sentry in `MovingBoxApp.swift`.

### Initialization
Sentry is initialized in `MovingBoxApp.init()`:

```swift
SentrySDK.start { options in
    options.dsn = "https://\(AppConfig.sentryDsn)"
    options.debug = AppConfig.shared.configuration == .debug
    options.tracesSampleRate = 0.2
    
    // Environment tracking
    #if DEBUG
    options.environment = "debug"
    #else
    options.environment = AppConfig.shared.buildType == .beta ? "beta" : "production"
    #endif
}
```

## Features

### Automatic Error Tracking
- Crashes and uncaught exceptions are automatically captured
- Native iOS crashes are tracked
- Swift errors are captured when thrown

### Environment Separation
- **Debug**: `environment = "debug"` - Full debug logging enabled
- **Beta**: `environment = "beta"` - Production tracking with beta flag
- **Production**: `environment = "production"` - Production tracking

### Performance Monitoring
- `tracesSampleRate = 0.2` - Captures 20% of transactions for performance analysis
- Tracks app launch time, network requests, and other performance metrics

### Debug Symbol Upload
The project includes a build phase script that automatically uploads debug symbols to Sentry for symbolicated crash reports. This runs during release builds.

## Testing

### Verify Integration
1. Build the project:
   ```bash
   xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
   ```

2. Check the console for Sentry initialization logs when running the app

### Manual Error Testing
To verify error tracking is working:

1. Add a test error in your code:
   ```swift
   enum TestError: Error {
       case sentryTest
   }
   SentrySDK.capture(error: TestError.sentryTest)
   ```

2. Or send a test message:
   ```swift
   SentrySDK.capture(message: "Test message from MovingBox")
   ```

3. Check your Sentry dashboard to verify the event was received

## Unit Tests

Basic integration tests are available in `MovingBoxTests/SentryIntegrationTests.swift`:
- Verifies Sentry DSN is configured
- Validates DSN format

## Troubleshooting

### Build Warnings
You may see a warning about the "Upload Debug Symbols to Sentry" build phase. This is normal and doesn't affect functionality. To resolve:
- Add output dependencies to the script phase, OR
- Uncheck "Based on dependency analysis" in the script phase settings

### Missing DSN
If you see "⚠️ Error: Missing Sentry DSN configuration" in debug logs:
1. Check that `MovingBox/Configuration/Base.xcconfig` exists and contains `SENTRY_DSN`
2. Verify the DSN is not set to `missing-sentry-dsn`
3. Clean build folder and rebuild

## Best Practices

1. **Don't Log Sensitive Data**: Never send PII (personally identifiable information) to Sentry
2. **Use Breadcrumbs**: Add context to errors with breadcrumbs for better debugging
3. **Set User Context**: Use `SentrySDK.setUser()` to track errors by user (with user consent)
4. **Tag Errors**: Use tags to categorize and filter errors in the Sentry dashboard

## Resources

- [Sentry iOS SDK Documentation](https://docs.sentry.io/platforms/apple/guides/ios/)
- [Sentry Cocoa GitHub](https://github.com/getsentry/sentry-cocoa)
- [MovingBox Project Configuration](MovingBox/Configuration/AppConfig.swift)
