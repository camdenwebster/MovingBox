# Services

Business logic and utilities for MovingBox.

## Key Services

| Service | Purpose | Protocol |
|---------|---------|----------|
| `OpenAIService` | AI image analysis via AIProxy | `OpenAIServiceProtocol` |
| `OptimizedImageManager` | Image storage/compression | `ImageManagerProtocol` |
| `DataManager` | CSV/ZIP export (actor) | - |
| `SettingsManager` | User preferences | `ObservableObject` |
| `RevenueCatManager` | Subscriptions | `ObservableObject` |
| `Router` | Navigation state | `ObservableObject` |
| `TelemetryManager` | Analytics (TelemetryDeck) | - |

## Mock Services for Testing

```swift
// OpenAI mock - use "Mock-OpenAI" launch argument
OpenAIServiceFactory.create() // Returns MockOpenAIService in test mode

// Mock configuration
let mock = MockOpenAIService()
mock.shouldFail = true           // Simulate API failure
mock.shouldFailMultiItem = true  // Simulate multi-item failure
mock.mockResponse = ImageDetails(...) // Custom response
```

## Service Injection Pattern

```swift
// App-level injection (MovingBoxApp.swift)
@StateObject private var settings = SettingsManager()
@StateObject private var router = Router()

// View access
@EnvironmentObject var settings: SettingsManager
@EnvironmentObject var router: Router
```

## OpenAI Service Notes
- Uses AIProxy SDK (not direct OpenAI calls)
- Partial key: `v2|5c7e57d7|ilrKAnl-45-YCHAB`
- Service URL: `https://api.aiproxy.com/1530daf2/e2ce41d0`
- Retry logic: 3 attempts with exponential backoff
- Token limits: Base 3000, +300 per image, 3x for high quality

## Image Storage
- Images stored via `OptimizedImageManager.shared`
- Path: `Documents/Images/{itemId}/`
- Thumbnails: `Documents/Thumbnails/{itemId}.jpg`
- Migration from `@Attribute(.externalStorage)` handled in model init

## Error Types
- `OpenAIError`: API errors with `userFriendlyMessage` and `isRetryable`
- `DataManager.DataError`: Export/import errors
