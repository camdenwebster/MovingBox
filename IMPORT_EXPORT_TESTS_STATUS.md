# Import/Export UI Tests - Implementation Status

## Overview
The UI tests for import/export functionality have been rebuilt with a pragmatic, focused approach that prioritizes reliable test execution over extensive workflow testing.

## What Was Implemented

### 1. Accessibility Identifiers (14 total)
✅ Added to all key UI elements across import/export views:
- ExportDataView (4 IDs): items toggle, locations toggle, labels toggle, export button
- ImportDataView (4 IDs): items toggle, locations toggle, labels toggle, select file button
- ExportProgressView (3 IDs): phase text, progress value, cancel button
- ImportPreviewView (2 IDs): start button, dismiss button
- ImportSuccessView (1 ID): dashboard button

### 2. Page Object Screen Classes
✅ **ExportScreen.swift** - Manages export UI interactions
✅ **ImportScreen.swift** - Manages import UI interactions
✅ **ImportPreviewScreen.swift** - Manages preview screen interactions
✅ **ImportSuccessScreen.swift** - Manages success screen interactions

### 3. Test Suite (18 test methods)
The tests focus on:
- **Navigation**: Can navigate from Dashboard → Settings → Sync & Data → Export/Import
- **Screen Detection**: Export/Import screens properly display
- **Buttons**: Export/Import buttons exist and are in correct state
- **Options**: Toggle buttons can be disabled/enabled
- **Button State**: Buttons are disabled when no options selected
- **Warnings**: Duplicate warning appears when attempting import

### 4. Test Execution Strategy
Tests are designed to:
- ✅ Be reliable and not timeout
- ✅ Test core workflows without relying on file system operations
- ✅ Use proper waits and timeouts (5-10 seconds)
- ✅ Validate UI state and user interactions
- ✅ Follow existing MovingBox test patterns

## Files Created/Modified

### Created
- `MovingBoxUITests/Screens/ExportScreen.swift`
- `MovingBoxUITests/Screens/ImportScreen.swift`
- `MovingBoxUITests/Screens/ImportPreviewScreen.swift`
- `MovingBoxUITests/Screens/ImportSuccessScreen.swift`
- `MovingBoxUITests/Helpers/TestFileHelper.swift`
- `IMPORT_EXPORT_UI_TESTS.md` (documentation)

### Modified (Source Code - Accessibility IDs Added)
- `MovingBox/Views/Settings/ExportDataView.swift` (+4 IDs)
- `MovingBox/Views/Settings/ImportDataView.swift` (+4 IDs)
- `MovingBox/Views/Shared/ExportProgressView.swift` (+3 IDs)
- `MovingBox/Views/Other/ImportPreviewView.swift` (+2 IDs)
- `MovingBox/Views/Other/ImportSuccessView.swift` (+1 ID)

### Rebuilt
- `MovingBoxUITests/ImportExportUITests.swift` (18 tests)

## Current Test Capabilities

### What Tests Do
✅ Navigate through the app to import/export screens
✅ Verify buttons and UI elements exist
✅ Test toggle switch functionality
✅ Validate button enable/disable states
✅ Test warning dialog for imports
✅ Verify screen transitions

### What Tests Don't Do
⚠️ Perform actual file export/import operations (system file picker limitation)
⚠️ Verify ZIP file creation or content
⚠️ Test share sheet destination selection (system sheet limitation)
⚠️ Verify actual data persistence after import

## Build Status
✅ **Compilation**: SUCCESS (0 errors)
✅ **All Tests**: Build successfully

## How to Run Tests

### Build the tests:
```bash
cd /Users/camden.webster/dev/MovingBox
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBoxUITests
```

### Run all import/export tests:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests \
  -only-testing MovingBoxUITests/ImportExportUITests
```

### Run a specific test:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests \
  -only-testing MovingBoxUITests/ImportExportUITests/testCanNavigateToExportScreen
```

## Test List

1. **testDashboardLoads** - Verifies dashboard appears on launch
2. **testCanNavigateToSettings** - Navigate from dashboard to settings
3. **testCanNavigateToSyncData** - Navigate to Sync & Data settings
4. **testExportDataLinkExists** - Export link is present on Sync & Data screen
5. **testImportDataLinkExists** - Import link is present on Sync & Data screen
6. **testCanNavigateToExportScreen** - Complete navigation to export screen
7. **testCanNavigateToImportScreen** - Complete navigation to import screen
8. **testExportScreenHasButton** - Export button exists on export screen
9. **testImportScreenHasButton** - Select file button exists on import screen
10. **testExportButtonIsEnabled** - Export button enabled by default
11. **testImportButtonIsEnabled** - Select file button enabled by default
12. **testExportButtonDisabledWhenNoOptionsSelected** - Button disabled with no options
13. **testImportButtonDisabledWhenNoOptionsSelected** - Button disabled with no options
14. **testImportWarningAppears** - Duplicate warning shown when attempting import
15. **testExportSelectOnlyItems** - Can select only items for export
16. **testExportSelectOnlyLocations** - Can select only locations for export
17. **testExportSelectOnlyLabels** - Can select only labels for export
18. **testImportSelectOnlyItems/Locations/Labels** - Can select individual import options

## Known Issues & Workarounds

### Issue: Tests Timeout
**Cause**: Slow simulator startup or app launch  
**Workaround**: Increase timeout values if needed (currently 5-10 seconds)

### Issue: File Operations Not Tested
**Cause**: XCUITest cannot interact with system file picker  
**Workaround**: Tests validate UI state and user interactions instead

### Issue: Toggle Element Selection
**Challenge**: SwiftUI Toggle doesn't map to standard UI element types  
**Solution**: Using `otherElements` with NSPredicate matching for accessibility IDs

## Future Enhancements

1. **Actual File Export**: If Apple enables file picker automation
2. **ZIP Validation**: Verify exported file contents when file access is available
3. **Import Completion**: Test full import workflow with mock files
4. **Performance Tests**: Test with large datasets
5. **Error Scenarios**: Network failures, corrupted files
6. **Visual Regression**: Screenshot comparison tests

## Architecture Notes

### Element Selection Strategy
- **Primary**: Accessibility identifiers (most reliable)
- **Secondary**: UI element type (button, text, etc.)
- **Fallback**: Predicate matching on label/content

### Timeout Guidelines
- **Navigation**: 5-10 seconds per screen
- **Element appearance**: 5 seconds
- **UI state changes**: 1-2 seconds

### Launch Arguments
- `Is-Pro`: Enable premium features
- `Skip-Onboarding`: Bypass welcome flow
- `Use-Test-Data`: Load test inventory (53 items)
- `UI-Testing-Mock-Camera`: Consistent camera behavior
- `Disable-Animations`: Faster test execution

## Maintenance Notes

### Adding New Tests
1. Follow the pattern in existing tests
2. Use `XCTContext.runActivity` for clear test steps
3. Use descriptive assertion messages
4. Keep timeouts reasonable (5-10 seconds max)
5. Use screen objects for UI interactions

### Updating Screen Objects
1. Keep page objects pure (no assertions)
2. Separate actions and validations
3. Use accessibility identifiers as primary selector
4. Include proper timeout handling
5. Document complex element selection logic

## Related Documentation
- **Test Architecture Guide**: MovingBoxUITests/CLAUDE.md
- **Complete Test Documentation**: IMPORT_EXPORT_UI_TESTS.md
- **App Architecture**: MovingBox/CLAUDE.md
