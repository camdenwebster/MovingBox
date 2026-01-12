# MovingBox

iOS AI-powered home inventory app. SwiftUI + SwiftData, OpenAI Vision API, RevenueCat, CloudKit.

## Project Configuration
- **Project**: MovingBox.xcodeproj
- **Scheme**: MovingBox (Tests: MovingBoxTests, MovingBoxUITests)
- **Bundle ID**: com.mothersound.movingbox
- **DerivedData**: ./DerivedData (in-project, preserves cache)
- **Simulator UDID**: 31D4A8DF-E68A-4884-BAAA-DFDF61090577 (iPhone 17 Pro, iOS 26)

## Build Commands
```bash
# Build (pipe through xcsift for clean output)
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./DerivedData 2>&1 | xcsift

# Unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./DerivedData 2>&1 | xcsift

# UI tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./DerivedData 2>&1 | xcsift
```

## Install & Launch
```bash
# Boot simulator
xcrun simctl boot 31D4A8DF-E68A-4884-BAAA-DFDF61090577

# Install app
xcrun simctl install 31D4A8DF-E68A-4884-BAAA-DFDF61090577 ./DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app

# Launch app
xcrun simctl launch 31D4A8DF-E68A-4884-BAAA-DFDF61090577 com.mothersound.movingbox

# Launch with arguments (for exploratory testing - UI tests already use the necessary arguments)
xcrun simctl launch 31D4A8DF-E68A-4884-BAAA-DFDF61090577 com.mothersound.movingbox --args -Mock-OpenAI -Use-Test-Data
```

## Test Launch Arguments
- `Mock-OpenAI` - Mock AI API (prevents real API calls)
- `Use-Test-Data` - Load test data
- `Disable-Animations` - Stable UI tests
- `Is-Pro` - Enable pro features
- `Skip-Onboarding` - Skip welcome flow
- `Show-Onboarding` - Force welcome flow
- `UI-Testing-Mock-Camera` - Mock camera for UI tests

## Logging
```bash
# Stream logs (filter by app)
xcrun simctl spawn 31D4A8DF-E68A-4884-BAAA-DFDF61090577 log stream --predicate 'subsystem == "com.mothersound.movingbox"'

# Or use print statements (appear in Xcode console and simctl output)
```

## Swift Package Documentation
After building, package docs available at: `./DerivedData/SourcePackages/checkouts/`

## Additional Context
- **DEVELOPMENT.md** - Architecture, patterns, SDLC workflow with Claude Code subagents
- Subdirectory CLAUDE.md files for detailed context (Services/, Models/, Views/, MovingBoxUITests/)
