# MovingBox
iOS AI-powered home inventory app. SwiftUI + SwiftData, OpenAI Vision API, RevenueCat, CloudKit.

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**
- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`

## Project Configuration
- **Project**: MovingBox.xcodeproj
- **Scheme**: MovingBox (Tests: MovingBoxTests, MovingBoxUITests)
- **Bundle ID**: com.mothersound.movingbox
- **DerivedData**: ./.build/DerivedData (in-project, preserves cache)
- **Simulator UDID**: 4DA6503A-88E2-4019-B404-EBBB222F3038 (iPhone 17 Pro, iOS 26.1)

## Build Commands
```bash
# Build (pipe through xcsift for clean output)
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift

# Unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift

# UI tests (Smoke tests) — grep filter preserves failure details that xcsift drops
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData -testPlan SmokeTests -resultBundlePath ./.build/SmokeTests-$(date +%Y%m%d-%H%M%S).xcresult 2>&1 | grep -E 'Test Case|: error:|Executed [0-9]+ test|\*\* TEST'
```

## Install & Launch
```bash
# Boot simulator
xcrun simctl boot 4DA6503A-88E2-4019-B404-EBBB222F3038

# Install app
xcrun simctl install 4DA6503A-88E2-4019-B404-EBBB222F3038 ./.build/DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app

# Launch app
xcrun simctl launch 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox

# Launch with arguments (for exploratory testing - UI tests already use the necessary arguments)
xcrun simctl launch 4DA6503A-88E2-4019-B404-EBBB222F3038 com.mothersound.movingbox --args -Mock-AI -Use-Test-Data
```

## Test Launch Arguments
- `Mock-AI` - Mock AI API (prevents real API calls)
- `Use-Test-Data` - Load test data
- `Disable-Animations` - Stable UI tests
- `Is-Pro` - Enable pro features
- `Skip-Onboarding` - Skip welcome flow
- `Show-Onboarding` - Force welcome flow
- `UI-Testing-Mock-Camera` - Mock camera for UI tests

## Logging
```bash
# Stream logs (filter by app)
xcrun simctl spawn 4DA6503A-88E2-4019-B404-EBBB222F3038 log stream --predicate 'subsystem == "com.mothersound.movingbox"'

# Or use print statements (appear in Xcode console and simctl output)
```

## Swift Package Documentation
After building, package docs available at: `./.build/DerivedData/SourcePackages/checkouts/`

## SwiftUI & iOS Best Practices

**IMPORTANT**: Follow these guidelines to avoid deprecated APIs and common mistakes. Use modern SwiftUI patterns.

### View Modifiers (Always Use Modern APIs)
- ✅ `.foregroundStyle()` ❌ `.foregroundColor()` - Supports gradients and advanced styling
- ✅ `.clipShape(.rect(cornerRadius:))` ❌ `.cornerRadius()` - Supports uneven rounded rectangles
- ✅ `.onChange(of: value) { oldValue, newValue in }` or `.onChange(of: value) { }` ❌ Single-parameter variant is deprecated
- ✅ `.fontWeight()` use sparingly - Prefer `.bold()` for semantic weights, or Dynamic Type scaling

### Layout & Sizing (Avoid GeometryReader Overuse)
- ❌ `GeometryReader` - **Massively overused by LLMs**, often unnecessarily
- ❌ Fixed `.frame(width:height:)` sizes - Breaks adaptive layouts and accessibility
- ✅ `.visualEffect { content, geometry in }` - Modern alternative for geometry-aware effects
- ✅ `.containerRelativeFrame()` - Size views relative to their container
- ✅ Let SwiftUI handle layout - Use flexible frames, spacing, padding instead
- **Cardinal Sin**: `GeometryReader` + fixed frames = rigid, non-adaptive layouts

### Navigation & Interaction
- ✅ `NavigationStack` ❌ `NavigationView` - Modern navigation API
- ✅ `navigationDestination(for:)` ❌ Inline destination NavigationLink in lists
- ✅ `Tab` API ❌ `.tabItem()` - Type-safe selection, iOS 26 search tab support
- ✅ `Button("Label", systemImage: "icon") { }` ❌ `Label` inside Button or image-only buttons
- ✅ `Button` with proper labels ❌ `onTapGesture()` - Better for VoiceOver and eye tracking
  - Exception: Use `onTapGesture()` only when you need tap location or count

### State Management & Observation
- ✅ `@Observable` macro ❌ `ObservableObject` - Simpler, faster, better view invalidation
- ✅ Separate SwiftUI views ❌ Computed properties for view composition
  - **Critical**: With `@Observable`, computed properties don't benefit from intelligent view invalidation
  - Split complex views into separate structs for better performance

### SwiftData & CloudKit
- ❌ `@Attribute(.unique)` does NOT work with CloudKit synchronization
- ✅ Use alternative validation patterns when iCloud sync is enabled
- ✅ All SwiftData operations require `ModelContext` from environment

### Typography & Accessibility
- ✅ Dynamic Type: `.font(.body)`, `.font(.title)`, `.font(.headline)`
- ✅ iOS 26+: `.font(.body.scaled(by: 1.5))` for proportional scaling
- ❌ `.font(.system(size: 16))` - Avoid fixed sizes; breaks accessibility
- ✅ Meaningful button labels for VoiceOver users

### Concurrency & Async Operations
- ✅ `Task.sleep(for: .seconds(1))` ❌ `Task.sleep(nanoseconds:)`
- ✅ `await MainActor.run { }` ❌ `DispatchQueue.main.async { }` - Use modern concurrency
- ✅ Main actor isolation is default in new app projects - no need for explicit `@MainActor` on AppDelegate/SceneDelegate

### Swift Standard Library
- ✅ `ForEach(x.enumerated(), id: \.element.id)` ❌ `ForEach(Array(x.enumerated()))`
- ✅ `URL.documentsDirectory` ❌ Long FileManager document directory code
- ✅ `Text(abs(value), format: .number.precision(.fractionLength(2)))`
- ❌ `Text(String(format: "%.2f", abs(value)))` - C-style formatting is error-prone

### Rendering & Graphics
- ✅ `ImageRenderer` ❌ `UIGraphicsImageRenderer` - For rendering SwiftUI views
- ✅ Modern SwiftUI drawing APIs

### Code Organization
- ✅ One type per file (or closely related types)
- ❌ Multiple unrelated types in single file - Increases build times significantly
- ✅ Follow MVVM: Views/ ViewModels/ Models/ structure

### Summary: Red Flags to Watch For
When reviewing code, immediately flag and fix:
- **GeometryReader overuse** - Check if visualEffect() or containerRelativeFrame() would work instead
- **Fixed frame sizes** - Especially combined with GeometryReader (the "cardinal sin")
- Deprecated modifiers (foregroundColor, cornerRadius, onChange single-param)
- NavigationView instead of NavigationStack
- onTapGesture without accessibility consideration
- ObservableObject instead of @Observable
- Fixed font sizes instead of Dynamic Type
- DispatchQueue.main.async in new concurrent code
- @Attribute(.unique) with CloudKit enabled

## Additional Context
- **DEVELOPMENT.md** - Architecture, patterns, SDLC workflow with Claude Code subagents
- Subdirectory CLAUDE.md files for detailed context (Services/, Models/, Views/, MovingBoxUITests/)
