# MovingBoxAI

Local Swift package that extracts AI business logic from the iOS app target.

## Modules

- `MovingBoxAIDomain`: domain types and error modeling (`ImageDetails`, `MultiItemAnalysisResponse`, `OpenAIError`, token usage models).
- `MovingBoxAICore`: pure business logic (`AIPromptConfiguration`, token budget calculation, JSON response decoding).

## Validation loop

```bash
cd Packages/MovingBoxAI
swift test --parallel
```

This package is intended to remain free of UIKit/SwiftUI and iOS-only SDK dependencies so it can run in Linux-based coding/test environments.
