# MovingBox Development Guide

This guide covers architecture, patterns, and the SDLC workflow for developing MovingBox.

## Architecture

### Core Data Flow
- **SwiftData Models**: `InventoryItem`, `InventoryLocation`, `InventoryLabel`, `Home`, `InsurancePolicy`
- **Managers**: App-level state managers injected as `@EnvironmentObject`
  - `SettingsManager` - User preferences and settings
  - `OnboardingManager` - Welcome flow state
  - `ModelContainerManager` - SwiftData container lifecycle
  - `RevenueCatManager` - Subscription management
- **Router**: Navigation coordinator using `NavigationStack` and `NavigationPath`

### Key Services
- **DataManager**: CSV/ZIP export functionality (actor-based)
- **OpenAIService**: AI-powered image analysis
- **OptimizedImageManager**: Image storage and compression
- **TelemetryManager**: Analytics via TelemetryDeck
- **DefaultDataManager**: Test data population

### Navigation Pattern
Uses centralized `Router` with tab-based navigation and programmatic routing:
- Tab enum defines 5 main tabs (Dashboard, Locations, Add Item, All Items, Settings)
- Destination enum for deep navigation within tabs
- Each tab maintains its own `NavigationPath`

### Image Management
- Migration pattern from SwiftData `@Attribute(.externalStorage)` to `OptimizedImageManager`
- Images stored outside Core Data for better performance
- Automatic migration with async/await pattern in model `init()`

## Code Style & Best Practices

### Swift Conventions
- **Naming**: Use `camelCase` for variables and functions, `PascalCase` for types and protocols
- **Access Control**: Prefer `private` and `fileprivate` when possible
- **SwiftUI**: Use `@StateObject` for owned objects, `@ObservedObject` for injected, `@EnvironmentObject` for app-wide state
- **Async/Await**: Prefer structured concurrency, use `actor` for thread-safe state

### File Organization
- **Models**: `/Models/` directory, one model per file
- **Views**: Organize by feature in `/Views/` subdirectories
- **Services**: Business logic in `/Services/`, use dependency injection
- **Tests**: Mirror source structure, use descriptive test names

### Testing Philosophy
- **TDD**: Write tests first for new features when feasible
- **Unit Tests**: Focus on business logic, use in-memory SwiftData containers
- **UI Tests**: Test critical user flows, use page object pattern
- **Snapshot Tests**: Verify visual consistency across light/dark modes

## SDLC with Claude Code Subagents

### Overview
```
1. Product Planning    → product-manager subagent + /create-prd
2. Technical Planning  → ios-architect subagent + /feature
3. Implementation     → swift-developer subagent + /process-tasks
4. Code Review        → code-reviewer subagent + /review-pr
5. Quality Assurance  → ios-qa-engineer subagent
6. UI/UX Validation   → ios-ux-designer subagent
7. Deployment        → DevOps processes + monitoring
```

### Core 3-Step Process

#### Step 1: PRD (`product-manager` subagent)
- Transform feature requests into structured PRDs
- Define user stories, acceptance criteria, success metrics
- Output: `prd-[feature-name].md`

#### Step 2: Technical Plan (`ios-architect` subagent)
- Translate PRD into technical architecture
- Break down into atomic development tasks (1-4 hours each)
- Output: Prioritized task list with dependencies

#### Step 3: Implementation (`swift-developer` subagent)
- Execute tasks incrementally following TDD
- Use native SwiftUI components (Forms, Lists, etc)
- Test thoroughly, commit regularly

### Supporting Roles
- **`ios-ux-designer`**: Visual design and UI consistency
- **`ios-qa-engineer`**: Testing and edge case validation
- **`code-reviewer`**: Security, quality, and standards adherence

### Workflow Variations

**Small Features/Bug Fixes:**
```
swift-developer + /fix → code-reviewer + /review-pr → QA validation
```

**Major Features:**
```
Full 7-phase SDLC + stakeholder reviews + beta testing
```

### Commit Guidelines
- Commit small, verifiable changes regularly
- Use conventional format: `feat:`, `fix:`, `refactor:`, `test:`
- Ensure all tests pass before committing

## Integration Points

### Third-Party Services
- **OpenAI Vision API**: Rate limits, retry logic, structured prompts
- **RevenueCat**: Pro feature gating, subscription state handling
- **TelemetryDeck**: User action tracking, privacy-respecting
- **CloudKit**: Sync conflicts, offline-first patterns

## Known Issues & Gotchas

### SwiftData Migration
- Image migration from `@Attribute(.externalStorage)` requires async handling
- Use `ModelContainerManager` for consistent container lifecycle

### OpenAI API
- Vision API has rate limits - implement exponential backoff
- Large images need compression via `OptimizedImageManager`

### UI Testing
- Disable animations for consistency
- Use appropriate launch arguments for test data
- Screenshot tests require consistent simulator state

## Performance Considerations

### Image Handling
- Use `OptimizedImageManager` for all storage
- Implement lazy loading for large collections
- Compress for network operations

### SwiftData
- Use appropriate fetch descriptors and predicates
- Implement pagination for large datasets
- Background contexts for heavy operations

## Security & Privacy

- Never log sensitive user data or API keys
- Store API keys in environment variables
- Validate all API responses
- Respect user consent for telemetry
- Follow App Store privacy guidelines
