# Views

SwiftUI views organized by feature area.

## Directory Structure

```
Views/
├── Items/          # Item add/edit/list/detail
├── Locations/      # Room and location management
├── Onboarding/     # Welcome flow
├── Other/          # Camera, miscellaneous
├── Settings/       # Settings and subscriptions
└── Shared/         # Reusable components
```

## Navigation Pattern

```swift
// Router-based navigation (5 tabs)
enum Tab: Int {
    case dashboard = 0
    case locations = 1
    case addItem = 2
    case allItems = 3
    case settings = 4
}

// Programmatic navigation
@EnvironmentObject var router: Router
router.navigate(to: .itemDetail(item))
router.selectedTab = .allItems
```

## State Management

```swift
// App-wide state (injected at root)
@EnvironmentObject var settings: SettingsManager
@EnvironmentObject var router: Router
@EnvironmentObject var onboarding: OnboardingManager
@EnvironmentObject var revenueCat: RevenueCatManager

// SwiftData access
@Environment(\.modelContext) private var modelContext
@Query var items: [InventoryItem]
```

## Shared Components (Views/Shared/)

| Component | Purpose |
|-----------|---------|
| `StatCard` | Dashboard statistics display |
| `ItemRow` | List item representation |
| `PhotoPicker` | Image selection UI |
| `LoadingView` | Async operation indicator |
| `EmptyStateView` | Empty list placeholder |

## Accessibility Identifiers

Use consistent naming for UI testing:
```swift
.accessibilityIdentifier("{feature}-{component}-{action}")

// Examples:
"inventory-item-save-button"
"dashboard-stats-card"
"settings-export-button"
"onboarding-continue-button"
```

## Preview Pattern

```swift
#Preview {
    ItemDetailView(item: TestData.sampleItem)
        .environment(\.modelContext, Previewer.shared.container.mainContext)
        .environmentObject(SettingsManager())
        .environmentObject(Router())
}
```

## Pro Feature Gating

```swift
// Check subscription status
if settings.isPro {
    // Show pro feature
} else {
    // Show paywall or limited version
}
```
