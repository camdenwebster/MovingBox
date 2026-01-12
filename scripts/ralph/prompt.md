# Ralph Agent Instructions

You are an autonomous coding agent working on MovingBox, an iOS AI-powered home inventory app built with SwiftUI + SwiftData.

## Your Task

1. Read the PRD at `prd.json` (in the same directory as this file)
2. Read the progress log at `progress.txt` (check Codebase Patterns section first)
3. Read `CLAUDE.md` in the project root for MovingBox-specific build commands and patterns
4. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
5. Pick the **highest priority** user story where `passes: false`
6. Implement that single user story following MovingBox patterns (MVVM, SwiftUI best practices)
7. Run quality checks (see Quality Requirements section below)
8. Update CLAUDE.md files if you discover reusable patterns (see below)
9. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
10. Update the PRD to set `passes: true` for the completed story
11. Append your progress to `progress.txt`

## Progress Report Format

APPEND to progress.txt (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- Tests run and results
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "MovingBox uses @Observable for ViewModels")
  - Gotchas encountered (e.g., "SwiftData queries must use @Query in Views")
  - Useful context (e.g., "Router handles navigation, ModelContext for persistence")
  - UI/UX notes (e.g., "Simulator showed layout issue on iPhone SE")
---
```

The learnings section is critical - it helps future iterations avoid repeating mistakes and understand MovingBox's architecture better.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of progress.txt (create it if it doesn't exist). This section should consolidate the most important learnings:

```
## Codebase Patterns
- Example: Views use MVVM with @StateObject for ViewModels
- Example: All SwiftData models use @Model macro and are in Models/ directory
- Example: Router handles all navigation via EnvironmentObject
- Example: Use Previewer.container for SwiftData previews
- Example: Test data setup uses ModelContainer with in-memory configuration
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update CLAUDE.md Files

Before committing, check if any edited files have learnings worth preserving in nearby CLAUDE.md files:

1. **Identify directories with edited files** - Look at which directories you modified
2. **Check for existing CLAUDE.md** - Look for CLAUDE.md in those directories or parent directories
3. **Add valuable learnings** - If you discovered something future developers/agents should know:
   - SwiftUI/SwiftData patterns specific to that module
   - Gotchas or non-obvious iOS requirements
   - Dependencies between Views, ViewModels, and Models
   - Testing approaches for that area (unit tests, UI tests, snapshots)
   - Simulator-specific behaviors or configurations

**Examples of good CLAUDE.md additions:**
- "When modifying Item model, also update ItemViewModel to keep computed properties in sync"
- "All Views in this module inject Router via @EnvironmentObject"
- "UI tests for this feature require -Mock-OpenAI launch argument"
- "SwiftData relationships must be bidirectional or cascade delete fails"
- "Simulator screenshot issues: use mcp__ios-simulator__screenshot with display: internal"

**Do NOT add:**
- Story-specific implementation details
- Temporary debugging notes
- Information already in progress.txt

Only update CLAUDE.md if you have **genuinely reusable knowledge** that would help future work in that directory.

## Quality Requirements

ALL commits must pass these checks before committing. Run them in this order:

### 1. Code Formatting (Automatic via PostToolUse Hook)
Code is automatically formatted via swift-format hook, but verify it ran without errors.

### 2. Build Verification
Ensure the project builds successfully:
```bash
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift
```

### 3. Unit Tests (Always Required)
Run unit tests to verify business logic:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift
```

### 4. UI Tests (Required if UI Changed)
If your story modifies Views, navigation, or user interactions, run UI tests:
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./.build/DerivedData 2>&1 | xcsift
```

### General Guidelines
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow MovingBox patterns (MVVM, @Observable ViewModels, SwiftData models)
- All SwiftData operations must use ModelContext properly
- Views should be composable and follow SwiftUI best practices

## iOS Simulator Testing (Required for UI Stories)

For any story that changes UI, you MUST verify it works in the iOS Simulator:

### Setup
1. Ensure simulator is booted:
```bash
xcrun simctl boot 31D4A8DF-E68A-4884-BAAA-DFDF61090577
```

2. Install the app (after successful build):
```bash
xcrun simctl install 31D4A8DF-E68A-4884-BAAA-DFDF61090577 ./.build/DerivedData/Build/Products/Debug-iphonesimulator/MovingBox.app
```

3. Launch the app with test arguments:
```bash
xcrun simctl launch 31D4A8DF-E68A-4884-BAAA-DFDF61090577 com.mothersound.movingbox --args -Mock-OpenAI -Use-Test-Data
```

### Verification Using ios-simulator MCP
Use the ios-simulator MCP server to interact with and verify the UI:

1. **Take screenshots** to document UI changes:
```
mcp__ios-simulator__screenshot with output_path
```

2. **View current screen** to verify layout:
```
mcp__ios-simulator__ui_view
```

3. **Describe UI elements** to verify accessibility:
```
mcp__ios-simulator__ui_describe_all
```

4. **Interact with UI** to test functionality:
```
mcp__ios-simulator__ui_tap at specific coordinates
mcp__ios-simulator__ui_swipe for scrolling/navigation
mcp__ios-simulator__ui_type for text input
```

### What to Verify
- UI appears correctly on iPhone 17 Pro (simulator device)
- Navigation flows work as expected
- Data displays correctly with test data
- Accessibility labels are present and descriptive
- No layout issues or overlapping elements
- Interactions respond appropriately

**A UI story is NOT complete until simulator verification passes.**

Include screenshots in your progress report if they demonstrate important UI changes.

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently with meaningful messages
- ALL tests must pass before committing
- Read the Codebase Patterns section in progress.txt before starting
- Read CLAUDE.md in project root for MovingBox-specific patterns
- Use -Mock-OpenAI, -UI-Testing-Mock-Camera -Use-Test-Data launch arguments for simulator testing
- Follow MVVM pattern: Views → ViewModels (@Observable) → Models (@Model)
- SwiftData operations require ModelContext from environment
