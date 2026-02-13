# Services

Business logic and utilities for MovingBox.

## Key Services

| Service | Purpose | Protocol |
|---------|---------|----------|
| `AIAnalysisService` | AI image analysis via AIProxy | `AIAnalysisServiceProtocol` |
| `OptimizedImageManager` | Image storage/compression | `ImageManagerProtocol` |
| `DataManager` | CSV/ZIP export (actor) | - |
| `SettingsManager` | User preferences | `ObservableObject` |
| `RevenueCatManager` | Subscriptions | `ObservableObject` |
| `Router` | Navigation state | `ObservableObject` |
| `TelemetryManager` | Analytics (TelemetryDeck) | - |

## Mock Services for Testing

```swift
// AI analysis mock - use "Mock-AI" launch argument
AIAnalysisServiceFactory.create() // Returns MockAIAnalysisService in test mode

// Mock configuration
let mock = MockAIAnalysisService()
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

## AI Analysis Service Notes
- Uses AIProxy SDK via OpenRouter (Gemini 3 Flash)
- Partial key: `v2|dd24c1ca|qVU7FksJSPDTvLtM`
- Service URL: `https://api.aiproxy.com/1530daf2/f9f2c62b`
- Model: `google/gemini-3-flash-preview`
- Retry logic: 3 attempts with exponential backoff
- Token limits: Base 3000, +300 per image, 3x for high quality

## Image Storage
- Images stored via `OptimizedImageManager.shared`
- Path: `Documents/Images/{itemId}/`
- Thumbnails: `Documents/Thumbnails/{itemId}.jpg`
- Migration from `@Attribute(.externalStorage)` handled in model init

## Error Types
- `AIAnalysisError`: API errors with `userFriendlyMessage` and `isRetryable`
- `DataManager.DataError`: Export/import errors
