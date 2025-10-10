# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MovingBox is an iOS app that uses AI to help users manage home inventory by taking photos and automatically cataloging items. Built with SwiftUI and SwiftData, integrated with OpenAI Vision API, RevenueCat for subscriptions, and CloudKit for data sync.

## Response Style
Respond in a concise and professional manner, keeping fluff to a minimum. Evaluate my ideas in an objective manner, and do not hesitate to challenge me if an idea is suboptimal, but give me reasoning as to why a different solution is more appropriate.

## Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild build -project MovingBox.xcodeproj -scheme MovingBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run UI tests  
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run snapshot tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# Generate App Store screenshots
fastlane screenshots
```

### Test Configuration
Use launch arguments for testing:
- `"Use-Test-Data"` - Load test data
- `"Mock-Data"` - Use mock data for snapshots
- `"Disable-Animations"` - Disable animations for tests
- `"Is-Pro"` - Enable pro features
- `"Skip-Onboarding"` - Skip onboarding flow

## Architecture
All new views should try to use MVVM where possible. Larger views should split the View and ViewModel into separate files, while smaller views could add the ViewModel as an extension on the view in the same file. Testability is critical.

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

### Testing Infrastructure
- **Unit Tests**: Swift Testing framework with in-memory SwiftData containers
- **UI Tests**: XCTest with page object model pattern (Screen objects)
- **Snapshot Tests**: `swift-snapshot-testing` with light/dark mode variants
- **Test Plans**: Organized via `.xctestplan` files for different test suites

### Configuration System
- **AppConfig**: Centralized config with build-specific behavior
- **Environment Variables**: JWT_SECRET, REVENUE_CAT_API_KEY, SENTRY_DSN, TELEMETRY_DECK_APP_ID
- **Build Types**: Production vs Beta with different feature flags
- **Launch Arguments**: Extensive testing configuration options

### Image Management
- Migration pattern from SwiftData `@Attribute(.externalStorage)` to `OptimizedImageManager`
- Images stored outside Core Data for better performance
- Automatic migration with async/await pattern in model `init()`

## Important Patterns

### Model Migration
When models need image migration, implement `migrateImageIfNeeded()` async method and call from model initializer

### AI Integration  
OpenAI Vision API calls use structured responses with retry logic and error handling in `OpenAIService`

### Subscription Handling
RevenueCat integration with pro feature gating via `AppConfig.shared.isPro` and subscription status

### Error Handling
Comprehensive error tracking with Sentry integration and structured error types for each service

## Code Style & Best Practices

### Swift Conventions
- **Naming**: Use `camelCase` for variables and functions, `PascalCase` for types and protocols
- **Access Control**: Prefer `private` and `fileprivate` when possible, explicit `public` for framework interfaces
- **Protocols**: Use protocol-oriented programming patterns, prefer composition over inheritance
- **SwiftUI**: Use `@StateObject` for owned objects, `@ObservedObject` for injected objects, `@EnvironmentObject` for app-wide state
- **Async/Await**: Prefer structured concurrency over completion handlers, use `actor` for thread-safe state management

### File Organization
- **Models**: Place in `/Models/` directory, one model per file
- **Views**: Organize by feature in `/Views/` subdirectories (Items, Locations, Onboarding, etc.)
- **Services**: Business logic and utilities in `/Services/`, use dependency injection patterns
- **Tests**: Mirror source structure in test directories, use descriptive test names

### Testing Philosophy
- **Test-Driven Development (TDD)**: Write tests first for new features when feasible
- **Unit Tests**: Focus on business logic, use in-memory SwiftData containers for isolation
- **UI Tests**: Test critical user flows, use page object pattern for maintainability
- **Snapshot Tests**: Verify visual consistency across light/dark modes and device sizes

## Complete Software Development Lifecycle (SDLC) with Claude Code

This guide outlines how to use Claude Code subagents and slash commands to manage the complete software development lifecycle for MovingBox, from initial feature concept to production deployment.

### SDLC Overview

```
1. Product Planning    → product-manager subagent + /create-prd
2. Technical Planning  → ios-architect subagent + /feature  
3. Task Planning      → Integrated into ios-architect subagent  
4. Implementation     → swift-developer subagent + /process-tasks
5. Code Review        → code-reviewer subagent + /review-pr
6. Quality Assurance  → ios-qa-engineer subagent + /test + /unittest
7. UI/UX Validation   → ios-ux-designer subagent + visual verification
8. Deployment        → DevOps processes + monitoring
```

## Core 3-Step Development Process

When working on complex features, use specialized Claude instances with subagents for a structured 3-step development process:

### Step 1: Product Requirements Document (PRD)
- **Agent**: `product-manager` subagent
- **Purpose**: Analyze user needs and create comprehensive feature requirements
- **Process**: Transform feature requests into structured PRDs with user stories, acceptance criteria, and success metrics
- **Output**: Detailed PRD with problem statement, requirements breakdown, and implementation phases

### Step 2: Technical Task List
- **Agent**: `ios-architect` subagent  
- **Purpose**: Translate PRD into detailed technical implementation plan
- **Process**: Analyze requirements → design architecture → break down into atomic development tasks
- **Output**: Prioritized task list with technical specifications, dependencies, and time estimates

### Step 3: Implementation
- **Agent**: `swift-developer` subagent
- **Purpose**: Execute tasks from technical plan with clean, maintainable code
- **Process**: Implement tasks incrementally → test thoroughly → commit regularly
- **Focus**: Follow established patterns, write self-documenting code, ensure quality. Use native SwiftUI components wherever possible (Forms, Lists, etc)

### Supporting Roles

#### UX Designer (`ios-ux-designer` subagent)
- **Purpose**: Implement visual designs and ensure UI consistency throughout development
- **When**: Use during implementation phase for UI-heavy tasks
- **Tools**: iOS Simulator screenshot capabilities for visual verification

#### QA Engineer (`ios-qa-engineer` subagent)
- **Purpose**: Comprehensive testing and quality assurance
- **When**: Use after implementation for thorough testing and edge case validation
- **Tools**: iOS Simulator automation and testing frameworks

#### Code Reviewer (`code-reviewer` subagent)
- **Purpose**: Review code quality, security, and adherence to standards
- **When**: Use before merging significant changes or complex features
- **Focus**: Security, maintainability, performance, and style consistency

## Detailed SDLC Phase Guide

### Phase 1: Product Planning (Product Manager)

**Objective**: Define WHAT to build based on user needs and business goals.

**Process**:
1. Use `product-manager` subagent or start new Claude session with product context
2. Use `/create-prd` command with feature description
3. Follow guided PRD creation process:
   - Answer clarifying questions about user problems
   - Define success metrics and user stories
   - Establish scope and non-goals
   - Consider MovingBox-specific aspects (AI integration, subscription model)

**Deliverables**:
- PRD document: `prd-[feature-name].md`
- Success metrics and KPIs
- User stories with acceptance criteria
- Scope definition and non-goals

### Phase 2: Technical Planning (iOS Architect)

**Objective**: Define HOW to build the feature within MovingBox's architecture.

**Process**:
1. Use `ios-architect` subagent or start new session with architect context
2. Provide PRD context and use `/feature` command
3. Review and approve architectural plan:
   - Evaluate technical approach and integration points
   - Consider performance, security, and scalability
   - Ensure alignment with existing patterns (SwiftUI, SwiftData, Router)
   - Break down into atomic development tasks

**Deliverables**:
- Technical architecture and implementation strategy
- Integration plan with existing services (OpenAI, RevenueCat, etc.)
- Performance considerations and constraints
- Risk assessment and mitigation strategies
- Detailed task list with dependencies and estimates

### Phase 3: Implementation (Swift Developer)

**Objective**: Implement the feature following the detailed task list.

**Process**:
1. Use `swift-developer` subagent or main Claude Code session
2. Use `/process-tasks` command with task list
3. Follow implementation protocol:
   - Implement one sub-task at a time
   - Wait for approval before proceeding
   - Run tests after each significant change
   - Update task list and documentation

**Deliverables**:
- Working feature with comprehensive test coverage
- Unit, integration, and UI tests
- Updated documentation and code comments
- Completed task list with verification

### Phase 4: Code Review (Code Reviewer)

**Objective**: Ensure code quality, security, and adherence to MovingBox standards.

**Process**:
1. Use `code-reviewer` subagent or start fresh session
2. Create pull request if using Git workflow
3. Use `/review-pr` command or provide code manually
4. Address review feedback and implement improvements

**Deliverables**:
- Comprehensive code review report
- Security and performance assessment
- Quality improvement recommendations
- Approved code ready for testing

### Phase 5: Quality Assurance (QA Engineer)

**Objective**: Comprehensive testing and quality validation.

**Process**:
1. Use `ios-qa-engineer` subagent
2. Execute testing commands:
   - `/test all` for comprehensive test suite
   - `/unittest [functionality]` for specific testing
3. Comprehensive testing approach:
   - Test different devices and orientations
   - Verify edge cases and error scenarios
   - Test with various data states and launch arguments

**Deliverables**:
- Complete test execution results
- Bug reports for any identified issues
- Test coverage analysis and gap identification
- Quality sign-off for production deployment

### Phase 6: UI/UX Validation (UX Designer)

**Objective**: Ensure visual design quality and user experience consistency.

**Process**:
1. Use `ios-ux-designer` subagent
2. Visual verification using iOS Simulator MCP integration
3. User experience testing:
   - Walk through user workflows
   - Test light/dark mode appearance
   - Verify accessibility features
   - Ensure consistency with existing patterns

**Deliverables**:
- Visual validation report with screenshots
- UX assessment and user flow validation
- Accessibility compliance audit
- Design sign-off for visual quality

### Phase 7: Deployment and Monitoring

**Objective**: Deploy feature and monitor production performance.

**Process**:
1. Final build verification: `/build release`
2. Follow established deployment procedures
3. Monitor app performance and analytics
4. Track feature usage via TelemetryDeck

**Deliverables**:
- Production deployment
- Performance monitoring setup
- User feedback collection
- Post-deployment analysis and iteration planning

## Claude Code Slash Commands Reference

### Core SDLC Commands
- `/create-prd [feature description]` - Create Product Requirements Document
- `/feature [implementation request]` - Generate technical architecture plan
- `/process-tasks [task-file.md]` - Execute development tasks systematically
- `/review-pr [#number]` - Comprehensive code review
- `/test all` - Run complete test suite
- `/unittest [functionality]` - Test specific functionality
- `/build release` - Final build verification

### Context Management Commands
- `/clear` - Reset context when switching roles
- `/agents` - Manage and create specialized subagents

### Workflow Variation Commands
- `/fix [issue]` - Quick fix for bugs and small issues

## Development Workflow Patterns

### Feature Development (Full SDLC)
Follow the complete 7-phase process for all new features:

1. **Create PRD** (`product-manager` subagent)
   - Analyze user requirements and business needs
   - Create comprehensive Product Requirements Document
   - Define success metrics and acceptance criteria
   - Break down into user stories and implementation phases

2. **Create Task List** (`ios-architect` subagent)
   - Translate PRD requirements into technical architecture
   - Design scalable, maintainable solutions within existing patterns
   - Break down into atomic development tasks (1-4 hours each)
   - Identify dependencies, risks, and implementation sequence

3. **Process Tasks** (`swift-developer` subagent)
   - Implement tasks incrementally following TDD principles
   - Write clean, self-documenting code
   - Test thoroughly and commit regularly
   - Use supporting subagents as needed (UX, QA, Code Review)

### Workflow Variations

#### Small Features/Bug Fixes
```
1. Developer Claude + /fix [issue]
2. Code Review Claude + /review-pr
3. QA validation with testing subagents
```

#### Emergency Hotfixes
```
1. Developer Claude + /fix [critical issue]
2. Immediate testing and deployment
3. Post-deployment review and documentation
```

#### Major Features
```
Full 7-phase SDLC process with additional:
- Stakeholder reviews after each phase
- Prototype validation with UX Designer
- Beta testing feedback integration
- Performance monitoring setup
```

### Bug Fixing
1. **Analysis**: Reproduce issue and identify root cause
2. **Fix Implementation**: Use `swift-developer` subagent for minimal, targeted fix
3. **Testing**: Use `ios-qa-engineer` subagent to verify fix and add regression tests
4. **Review**: Use `code-reviewer` subagent to validate approach before merging

### Commit Guidelines
- **Frequency**: Commit small, verifiable changes regularly
- **Messages**: Use conventional commit format (feat:, fix:, refactor:, test:)
- **Testing**: Ensure all tests pass before committing
- **Linting**: Run project linting tools before commits

## SDLC Best Practices and Quality Gates

### Context Management
- **Start fresh sessions** for different roles to maintain objectivity
- **Use `/clear`** when switching contexts within same session
- **Document handoffs** between phases with clear context
- **Save deliverables** from each phase (PRD, plans, task lists)
- **Reference previous work** when starting new phases

### Quality Gates
- **Don't skip phases** - each provides valuable perspective and validation
- **Validate deliverables** before proceeding to next phase
- **Address feedback** from review phases before deployment
- **Maintain traceability** from requirements through implementation

### Success Metrics

#### Process Quality
- **Requirements Traceability**: All implemented features trace back to PRD requirements
- **Test Coverage**: Comprehensive testing at unit, integration, and UI levels
- **Code Quality**: Consistent adherence to MovingBox patterns and Swift conventions
- **Documentation**: Complete and current documentation throughout

#### Delivery Quality
- **Bug Rate**: Low defect rate in production deployment
- **Performance**: Features meet performance expectations and benchmarks
- **User Satisfaction**: Positive user feedback and feature adoption
- **Maintainability**: Code is easy to understand, modify, and extend

### Troubleshooting Common Issues

#### Context Loss Between Phases
**Problem**: Claude forgets previous context when switching roles
**Solution**: 
- Save deliverables as files and reference them explicitly
- Provide clear context setting at start of each phase
- Use this CLAUDE.md file for consistent project context

#### Scope Creep During Implementation
**Problem**: Feature grows beyond original requirements
**Solution**:
- Refer back to PRD for scope validation and boundaries
- Use "non-goals" section to stay focused on core requirements
- Address new requirements through formal change process

#### Quality Issues During Review
**Problem**: Code doesn't meet standards during review phase
**Solution**:
- Return to Developer Claude with specific, actionable feedback
- Update implementation following review guidelines
- Re-run quality assurance validation before proceeding

#### Integration Problems
**Problem**: Feature doesn't integrate well with existing systems
**Solution**:
- Return to Architect Claude for integration planning review
- Review this CLAUDE.md file for integration patterns and constraints
- Test integration points more thoroughly with realistic data

## Integration Points

### Third-Party Services
- **OpenAI Vision API**: Handle rate limits, implement retry logic, structure prompts for consistency
- **RevenueCat**: Gate pro features appropriately, handle subscription state changes
- **TelemetryDeck**: Track key user actions, respect privacy settings
- **CloudKit**: Handle sync conflicts, implement offline-first patterns

### Platform Integration
- **iOS Simulator**: Use for testing and visual verification during development
- **Xcode**: Leverage build configurations for different environments
- **TestFlight**: Coordinate beta testing and feedback collection

## Known Issues & Gotchas

### SwiftData Migration
- Image migration from `@Attribute(.externalStorage)` requires careful async handling
- Test with various data states during migration development
- Use `ModelContainerManager` for consistent container lifecycle

### OpenAI API
- Vision API has rate limits, implement exponential backoff
- Large images may need compression via `OptimizedImageManager`
- Structure prompts consistently for reliable parsing

### UI Testing
- Disable animations in test environment for consistency
- Use appropriate launch arguments for test data scenarios
- Screenshot tests require consistent simulator state

## Performance Considerations

### Image Handling
- Use `OptimizedImageManager` for all image storage
- Implement lazy loading for large photo collections
- Consider image compression for network operations

### SwiftData Optimization
- Use appropriate fetch descriptors and predicates
- Implement pagination for large datasets
- Consider background contexts for heavy operations

### Memory Management
- Use weak references in closures appropriately
- Monitor memory usage during image processing
- Implement proper cleanup in view lifecycle

## Security & Privacy

### Data Protection
- Never log sensitive user data or API keys
- Use secure storage for authentication tokens
- Implement proper data validation and sanitization

### API Security
- Store API keys in environment variables or secure configuration
- Validate all OpenAI API responses
- Implement proper error handling without exposing internal state

### User Privacy
- Respect user consent for telemetry
- Implement proper data export/deletion capabilities
- Follow App Store privacy guidelines
