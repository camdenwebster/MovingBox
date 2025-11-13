# Import/Export UI Tests Documentation

## Overview

This document describes the rebuilt UI tests for the MovingBox import/export features. The tests follow the Page Object Model pattern and are designed to comprehensively validate the improved import/export workflows.

## Accessibility Identifiers

All import/export UI elements have been tagged with accessibility identifiers for reliable testing.

### Export Screen Identifiers

| Element | ID | View |
|---------|-----|------|
| Items Toggle | `export-items-toggle` | ExportDataView |
| Locations Toggle | `export-locations-toggle` | ExportDataView |
| Labels Toggle | `export-labels-toggle` | ExportDataView |
| Export Button | `export-data-button` | ExportDataView |
| Progress Phase Text | `export-progress-phase-text` | ExportProgressView |
| Progress Value | `export-progress-value` | ExportProgressView |
| Cancel Button | `export-cancel-button` | ExportProgressView |

### Import Screen Identifiers

| Element | ID | View |
|---------|-----|------|
| Items Toggle | `import-items-toggle` | ImportDataView |
| Locations Toggle | `import-locations-toggle` | ImportDataView |
| Labels Toggle | `import-labels-toggle` | ImportDataView |
| Select File Button | `import-select-file-button` | ImportDataView |
| Start Button | `import-preview-start-button` | ImportPreviewView |
| Dismiss Button | `import-preview-dismiss-button` | ImportPreviewView |
| Dashboard Button | `import-success-dashboard-button` | ImportSuccessView |

## Screen Page Objects

### ExportScreen

**File:** `MovingBoxUITests/Screens/ExportScreen.swift`

**Responsibilities:**
- Manage export UI element interactions
- Toggle export options (items, locations, labels)
- Monitor export progress
- Validate button states

**Key Methods:**
- `isDisplayed()` - Verify export screen is visible
- `tapExportButton()` - Initiate export
- `tapCancelButton()` - Cancel export operation
- `toggleItems(Bool)` - Toggle items export option
- `toggleLocations(Bool)` - Toggle locations export option
- `toggleLabels(Bool)` - Toggle labels export option
- `enableAllOptions()` - Select all export options
- `disableAllOptions()` - Deselect all options
- `selectOnlyItems/Locations/Labels()` - Select single option
- `waitForExportProgress()` - Wait for progress indicator
- `waitForProgressCompletion()` - Wait for share sheet
- `isExportButtonEnabled()` / `isExportButtonDisabled()` - Check button state

### ImportScreen

**File:** `MovingBoxUITests/Screens/ImportScreen.swift`

**Responsibilities:**
- Manage import UI element interactions
- Toggle import options
- Handle duplicate warning alerts

**Key Methods:**
- `isDisplayed()` - Verify import screen is visible
- `tapSelectFileButton()` - Initiate file selection
- `toggleItems/Locations/Labels(Bool)` - Toggle import options
- `enableAllOptions()` - Select all options
- `disableAllOptions()` - Deselect all options
- `selectOnlyItems/Locations/Labels()` - Select single option
- `waitForDuplicateWarning()` - Wait for warning alert
- `acceptDuplicateWarning()` - Confirm import with duplicates
- `dismissDuplicateWarning()` - Cancel file selection
- `isSelectFileButtonEnabled()` / `isSelectFileButtonDisabled()` - Check button state

### ImportPreviewScreen

**File:** `MovingBoxUITests/Screens/ImportPreviewScreen.swift`

**Responsibilities:**
- Validate import preview display
- Manage import confirmation flow
- Monitor import progress

**Key Methods:**
- `isDisplayed()` - Verify preview screen is visible
- `tapStartButton()` - Confirm and start import
- `tapDismissButton()` - Cancel import
- `waitForImporting()` - Wait for import to begin
- `waitForImportComplete()` - Wait for import completion
- `waitForErrorState()` - Wait for error display
- `getErrorMessage()` - Retrieve error text
- `isStartButtonEnabled()` / `isStartButtonDisabled()` - Check button state

### ImportSuccessScreen

**File:** `MovingBoxUITests/Screens/ImportSuccessScreen.swift`

**Responsibilities:**
- Validate import success display
- Confirm import results
- Navigate after successful import

**Key Methods:**
- `isDisplayed()` - Verify success screen is visible
- `tapDashboardButton()` - Navigate to dashboard
- `waitForCheckmark()` - Wait for success animation
- `hasImportedItems()` / `hasImportedLocations()` / `hasImportedLabels()` - Validate import results

## Test Cases

### Export Tests

#### testExportAllDataTypes()
Tests complete export workflow with all data types selected.
- Navigates to export screen
- Verifies all options are selected by default
- Initiates export
- Validates progress display
- Confirms share sheet appears

#### testExportItemsOnly()
Tests export with only items selected.
- Selects items-only option
- Validates export button is enabled
- Confirms export completes

#### testExportLocationsOnly()
Tests export with only locations selected.
- Selects locations-only option
- Validates export button is enabled
- Confirms export completes

#### testExportLabelsOnly()
Tests export with only labels selected.
- Selects labels-only option
- Validates export button is enabled
- Confirms export completes

#### testExportNoOptionsSelected()
Edge case: attempts export with no options selected.
- Deselects all options
- Verifies export button is disabled
- Confirms alert appears when attempting export

#### testExportOptionsToggle()
Tests toggle state management on export screen.
- Toggles individual options on/off
- Validates button enable/disable state
- Confirms proper state transitions

### Import Tests

#### testImportNoOptionsSelected()
Edge case: attempts import with no options selected.
- Deselects all options
- Verifies select file button is disabled

#### testImportWithAllOptionsSelected()
Tests import with all options selected.
- Enables all options
- Taps select file button
- Confirms duplicate warning appears

#### testImportDuplicateWarningCancel()
Tests warning dismissal workflow.
- Enables options and triggers file selection
- Confirms warning appears
- Dismisses warning via Cancel button
- Validates return to import screen

#### testImportOptionsToggle()
Tests toggle state management on import screen.
- Toggles individual options on/off
- Validates button enable/disable state

#### testExportAndImportFlow()
End-to-end test: export then import workflow.
- Records initial item count
- Exports all data
- Returns to dashboard
- Navigates to import screen
- Confirms duplicate warning appears

## Helper Classes

### TestFileHelper

**File:** `MovingBoxUITests/Helpers/TestFileHelper.swift`

**Responsibilities:**
- Manage test files and directories
- Locate exported ZIP files
- Clean up test files

**Key Methods:**
- `getExportedZipFileURL()` - Find most recent ZIP file
- `clearTestFiles()` - Remove all test files
- `getDownloadsDirectory()` - Access downloads folder
- `findLatestDownloadedZip()` - Locate most recent downloaded ZIP

## Test Configuration

### Launch Arguments

| Argument | Purpose |
|----------|---------|
| `Is-Pro` | Enable pro features including import/export |
| `Skip-Onboarding` | Bypass welcome flow |
| `Use-Test-Data` | Load test inventory (53 items) |
| `UI-Testing-Mock-Camera` | Mock camera for consistency |
| `Disable-Animations` | Speed up test execution |

### Test Setup

Each test:
1. Launches app with test configuration
2. Initializes all screen objects
3. Waits for dashboard to display
4. Performs test activities

### Teardown

- Cleans up screen object references
- Allows app to reset for next test

## Running Tests

### Build UITests

```bash
cd /Users/camden.webster/dev/MovingBox
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | xcsift
```

### Run Specific Test

```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -testPlan MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing MovingBoxUITests/ImportExportUITests/testExportAllDataTypes
```

### Run All Import/Export Tests

```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -testPlan MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing MovingBoxUITests/ImportExportUITests
```

## Navigation Flow

### Export Navigation
1. Dashboard
2. Tap Settings button
3. Settings screen
4. Tap "Sync & Data"
5. Sync & Data settings
6. Tap "Export Data" link
7. Export screen

### Import Navigation
1. Dashboard
2. Tap Settings button
3. Settings screen
4. Tap "Sync & Data"
5. Sync & Data settings
6. Tap "Import Data" link
7. Import screen
8. (If file selected) Import Preview screen
9. (If confirmed) Import Success screen

## Known Limitations

1. **File Picker**: UITests cannot directly interact with the system file picker. The tests validate the workflow up to file selection initiation.

2. **Share Sheet**: Share sheet interactions are mocked. Tests validate that the share sheet appears but cannot verify the save destination.

3. **Actual File Import**: Tests validate the import preview and confirmation flows but don't perform actual file operations in the test environment.

## Future Enhancements

1. **File Picker Automation**: Implement XCUIElementTypeFileBrowser interaction for actual file selection
2. **Share Sheet Handling**: Mock or handle system share sheet interactions
3. **File Content Validation**: Verify actual ZIP contents and data integrity
4. **Performance Testing**: Add tests for large dataset import/export
5. **Error Scenario Testing**: Test network failures and corrupted files

## Troubleshooting

### Tests Timeout on Progress

**Issue**: Export progress indicator never appears.
**Solution**: 
- Verify export data is not too large (test data has 53 items)
- Check export progress timeout (currently 30 seconds)
- Ensure `Use-Test-Data` launch argument is set

### Import Warning Doesn't Appear

**Issue**: Duplicate warning alert not found.
**Solution**:
- Verify import options are enabled before tapping select file
- Check alert exists before timeout (5 seconds)
- Try waiting longer if test data is loading slowly

### Navigation Fails

**Issue**: Cannot navigate to settings or import/export screens.
**Solution**:
- Verify `Skip-Onboarding` launch argument
- Check that dashboard displays before navigating
- Confirm sync/data screen exists (may require scrolling)
- Verify `Is-Pro` flag is set to enable import/export

## Related Documentation

- **UI Testing Guide**: `MovingBoxUITests/CLAUDE.md`
- **Project Architecture**: `/MovingBox/CLAUDE.md`
- **App Views**: `MovingBox/Views/Settings/ExportDataView.swift`, `ImportDataView.swift`
