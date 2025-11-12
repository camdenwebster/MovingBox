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

    options.configureProfiling = {
        $0.lifecycle = .trace
        $0.sessionSampleRate = 1
    }

    // Session Replay
    options.sessionReplay.onErrorSampleRate = 1.0
    options.sessionReplay.sessionSampleRate = 0.1

    // Logs
    options.experimental.enableLogs = true

    // Automatic iOS Instrumentation (most features enabled by default in v8+)
    // Only configure non-default settings:
    options.enablePreWarmedAppStartTracing = true  // Disabled by default, enable for iOS 15+
    options.enableTimeToFullDisplayTracing = true  // Disabled by default

    // Network Tracking - limit to OpenAI API proxy only for privacy
    options.tracePropagationTargets = ["api.aiproxy.com"]

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

### Performance Monitoring
- `tracesSampleRate = 0.2` - Captures 20% of transactions for performance analysis
- **Profiling**: Enabled for all traces with 100% sample rate

#### Automatic Instrumentation (Enabled by Default in v8+)
The following features are **automatically enabled** and require no configuration:
- **UIViewController Tracing**: Tracks native UIViewController load times
- **App Start Tracking**: Measures cold and warm app start times
- **Frame Tracking**: Detects slow (>16ms) and frozen (>700ms) frames
- **Network Tracking**: Monitors all URLSession HTTP requests
- **File I/O Tracking**: Instruments NSData operations
- **Core Data Tracking**: Traces fetch and save operations
- **User Interaction Tracking**: Captures UI interaction transactions

#### Explicitly Enabled Features
- **Prewarmed App Start Tracking**: iOS 15+ prewarmed app start detection (disabled by default)
- **Time to Full Display**: Measures perceived performance - call `SentrySDK.reportFullyDisplayed()` when fully loaded

#### Network Tracking Configuration
- **tracePropagationTargets**: Limited to `["api.aiproxy.com"]` for privacy
- This restricts Sentry trace headers to only OpenAI API proxy calls, preventing data leakage to other domains

### Session Replay
- **On Errors**: 100% of sessions with errors are recorded
- **General Sessions**: 10% sample rate for user session recording
- Provides video-like replay of user sessions with performance metrics

### Logging
- **Experimental Logs**: Enabled to send log messages to Sentry

### Environment Separation
- **Debug**: `environment = "debug"` - Full debug logging enabled
- **Beta**: `environment = "beta"` - Production tracking with beta flag
- **Production**: `environment = "production"` - Production tracking

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

## SwiftUI View Tracing (Optional)

MovingBox is built with SwiftUI. While Sentry automatically tracks UIViewController loads, SwiftUI views require manual instrumentation using the `SentrySwiftUI` package (already included).

### Adding View Tracing

To trace specific SwiftUI views, import `SentrySwiftUI` and wrap views:

```swift
import SentrySwiftUI

var body: some View {
    SentryTracedView("InventoryDetailView") {
        // Your view code
    }
}

// Or use the modifier syntax:
var body: some View {
    List {
        // Your list content
    }
    .sentryTrace("InventoryListView")
}
```

### Recommended Views to Trace

Priority views for performance monitoring:
1. **InventoryDetailView** - Photo-heavy, AI analysis
2. **InventoryListView** - Large dataset scrolling
3. **ImageAnalysisView** - AI processing UI
4. **HorizontalPhotoScrollView** - Image loading performance
5. **DashboardView** - App entry point
6. **ExportDataView** - Heavy operations

### Nested Tracing

For detailed performance analysis, trace sub-components:

```swift
SentryTracedView("InventoryDetailView") {
    VStack {
        SentryTracedView("PhotoCarousel") {
            HorizontalPhotoScrollView(...)
        }

        SentryTracedView("ItemDetails") {
            // Form fields
        }
    }
}
```

## Best Practices

1. **Don't Log Sensitive Data**: Never send PII (personally identifiable information) to Sentry
2. **Use Breadcrumbs**: Add context to errors with breadcrumbs for better debugging
3. **Set User Context**: Use `SentrySDK.setUser()` to track errors by user (with user consent)
4. **Tag Errors**: Use tags to categorize and filter errors in the Sentry dashboard
5. **Report Full Display**: Call `SentrySDK.reportFullyDisplayed()` when views are fully loaded
6. **Network Privacy**: `tracePropagationTargets` limits tracking to specified domains only

## Resources

- [Sentry iOS SDK Documentation](https://docs.sentry.io/platforms/apple/guides/ios/)
- [Sentry Cocoa GitHub](https://github.com/getsentry/sentry-cocoa)
- [MovingBox Project Configuration](MovingBox/Configuration/AppConfig.swift)
