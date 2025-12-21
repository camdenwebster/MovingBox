# WhatsNewKit Integration

## Overview
WhatsNewKit has been integrated into MovingBox to showcase new features to users when the app is updated. The integration follows the automatic presentation pattern, displaying "What's New" screens when appropriate.

## Files Added

### Configuration
- **`MovingBox/Configuration/WhatsNewConfiguration.swift`**
  - Defines `WhatsNew` instances for each version
  - Current version: 2.1.0 with features:
    - Multi-Item Analysis flow
    - Enhanced Import & Export capabilities
    - Better sorting options
    - Improved iPad & Mac experience
  - Provides convenience extensions for easy configuration

## Files Modified

### App Entry Point
- **`MovingBoxApp.swift`**
  - Added `import WhatsNewKit`
  - Configured WhatsNewEnvironment in the environment chain
  - Uses `UserDefaultsWhatsNewVersionStore` to track which versions have been shown

### Dashboard View
- **`MovingBox/Views/Home Views/DashboardView.swift`**
  - Added `import WhatsNewKit`
  - Added `.whatsNewSheet()` modifier to automatically present What's New on app launch
  - Presentation happens after splash screen and onboarding (if needed)

### About View
- **`MovingBox/Views/Settings/AboutView.swift`**
  - Added `import WhatsNewKit`
  - Changed "What's New" from external link to button that presents WhatsNewKit sheet
  - Added `@State private var whatsNew: WhatsNew?` to manage presentation
  - Button sets `whatsNew = .current` to trigger manual presentation
  - Uses `.sheet(whatsNew:)` modifier for presentation

## How It Works

### Automatic Presentation
1. User launches the app
2. WhatsNewEnvironment checks if current version has been presented
3. If not, WhatsNewKit automatically presents the What's New sheet on DashboardView
4. Once dismissed, version is saved to UserDefaults
5. User won't see the same version's What's New again

### Manual Presentation
1. User navigates to Settings → About
2. User taps "What's New" button
3. Current version's What's New sheet is presented
4. User can view features any time they want

## Version Storage
WhatsNewKit uses `UserDefaultsWhatsNewVersionStore` which persists presented versions in UserDefaults under the key that WhatsNewKit manages internally. This ensures:
- Users see What's New only once per version
- Clean separation of concerns
- Easy to test (can clear UserDefaults)

## Adding New Versions

To add a new version's What's New content:

1. Open `MovingBox/Configuration/WhatsNewConfiguration.swift`
2. Add a new static property (e.g., `version2_2_0`):

```swift
static var version2_2_0: WhatsNew {
    WhatsNew(
        version: "2.2.0",
        title: "What's New",
        features: [
            WhatsNew.Feature(
                image: .init(
                    systemName: "star.fill",
                    foregroundColor: .yellow
                ),
                title: "New Feature",
                subtitle: "Description of new feature"
            )
            // Add more features...
        ],
        primaryAction: WhatsNew.PrimaryAction(
            title: "Continue",
            backgroundColor: .accentColor,
            foregroundColor: .white,
            hapticFeedback: .notification(.success)
        )
    )
}
```

3. Update the `current` property:
```swift
static var current: WhatsNew {
    version2_2_0
}
```

4. Add to the collection in `forMovingBox`:
```swift
whatsNewCollection: [
    .version2_1_0,
    .version2_2_0  // Add new version
]
```

## Customization Options

### Layout
You can customize the layout by passing a `WhatsNew.Layout` parameter:

```swift
.whatsNewSheet(
    layout: WhatsNew.Layout(
        contentPadding: .init(top: 80, leading: 20, bottom: 20, trailing: 20),
        featureListSpacing: 35,
        showsScrollViewIndicators: true
    )
)
```

### Secondary Actions
Add a secondary action for additional functionality:

```swift
secondaryAction: WhatsNew.SecondaryAction(
    title: "Learn More",
    foregroundColor: .accentColor,
    hapticFeedback: .selection,
    action: .openURL(
        .init(string: "https://movingbox.ai/release-notes")
    )
)
```

## Testing

### Testing Automatic Presentation
To test automatic presentation, clear UserDefaults:
```swift
UserDefaults.standard.removeObject(forKey: "com.whatsnewkit.presented-versions")
```

Or use the in-memory version store for testing:
```swift
.environment(\.whatsNew, .forMovingBox(versionStore: InMemoryWhatsNewVersionStore()))
```

### Testing Manual Presentation
Simply tap the "What's New" button in Settings → About to verify the sheet appears correctly.

## Resources
- [WhatsNewKit GitHub](https://github.com/SvenTiigi/WhatsNewKit)
- [WhatsNewKit Documentation](https://sventiigi.github.io/WhatsNewKit/documentation/whatsnewkit/)
