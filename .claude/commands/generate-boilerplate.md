# Generate Boilerplate

Generate boilerplate code for a new iOS component/pattern in MovingBox: $ARGUMENTS

## Boilerplate Types

### SwiftUI View with ViewModel (MVVM)
Generate a new SwiftUI view following the MVVM pattern:

**View Template:**
```swift
import SwiftUI

struct {{ViewName}}View: View {
    @StateObject private var viewModel = {{ViewName}}ViewModel()
    @EnvironmentObject private var router: Router
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            VStack {
                // View content here
                Text("{{ViewName}} View")
                    .font(.title)
            }
            .navigationTitle("{{ViewName}}")
            .toolbar {
                // Toolbar items
            }
        }
        .onAppear {
            viewModel.setup()
        }
    }
}

#Preview {
    {{ViewName}}View()
        .environmentObject(Router())
        .modelContainer(Previewer.container)
}
```

**ViewModel Template:**
```swift
import Foundation
import SwiftData
import Observation

@Observable
class {{ViewName}}ViewModel {
    private var modelContext: ModelContext?
    
    // MARK: - State Properties
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Setup
    func setup() {
        // Initialize view model
    }
    
    // MARK: - Actions
    func performAction() {
        Task {
            await handleAction()
        }
    }
    
    @MainActor
    private func handleAction() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Perform async work
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### SwiftData Model
Generate a new SwiftData model with standard patterns:

```swift
import Foundation
import SwiftData

@Model
final class {{ModelName}} {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Relationships
    // Define relationships here
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }
}

// MARK: - Computed Properties
extension {{ModelName}} {
    // Add computed properties here
}

// MARK: - Protocol Conformance
extension {{ModelName}}: Identifiable {
    // Already conforms via @Model
}
```

### Service Class with Protocol
Generate a new service following dependency injection patterns:

**Protocol Template:**
```swift
import Foundation

protocol {{ServiceName}}Protocol {
    func performOperation() async throws -> {{ResultType}}
    func handleData(_ data: {{DataType}}) async throws
}
```

**Service Implementation:**
```swift
import Foundation
import OSLog

final class {{ServiceName}}: {{ServiceName}}Protocol, ObservableObject {
    private let logger = Logger(subsystem: "com.movingbox.app", category: "{{ServiceName}}")
    
    // MARK: - Dependencies
    // Inject dependencies here
    
    init() {
        // Initialize service
    }
    
    // MARK: - {{ServiceName}}Protocol
    func performOperation() async throws -> {{ResultType}} {
        logger.info("Performing operation")
        
        do {
            // Implementation here
            let result = {{ResultType}}()
            return result
        } catch {
            logger.error("Operation failed: \(error.localizedDescription)")
            throw {{ServiceName}}Error.operationFailed(error)
        }
    }
    
    func handleData(_ data: {{DataType}}) async throws {
        logger.info("Handling data")
        
        // Implementation here
    }
}

// MARK: - Error Types
enum {{ServiceName}}Error: Error, LocalizedError {
    case operationFailed(Error)
    case invalidData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .operationFailed(let error):
            return "Operation failed: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data provided"
        case .networkError:
            return "Network error occurred"
        }
    }
}
```

### Manager (Environment Object)
Generate a new app-level manager:

```swift
import Foundation
import SwiftUI
import OSLog

final class {{ManagerName}}: ObservableObject {
    private let logger = Logger(subsystem: "com.movingbox.app", category: "{{ManagerName}}")
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var currentState: {{ManagerName}}State = .idle
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setup()
    }
    
    // MARK: - Setup
    private func setup() {
        logger.info("Setting up {{ManagerName}}")
        // Initialize manager
        isInitialized = true
    }
    
    // MARK: - Public Methods
    func performAction() {
        Task {
            await handleAction()
        }
    }
    
    @MainActor
    private func handleAction() async {
        currentState = .loading
        
        do {
            // Perform async work
            currentState = .success
        } catch {
            logger.error("Action failed: \(error.localizedDescription)")
            currentState = .error(error)
        }
    }
}

// MARK: - State Enum
enum {{ManagerName}}State: Equatable {
    case idle
    case loading
    case success
    case error(Error)
    
    static func == (lhs: {{ManagerName}}State, rhs: {{ManagerName}}State) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.success, .success):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
```

### Custom SwiftUI View Modifier
Generate reusable view modifiers:

```swift
import SwiftUI

struct {{ModifierName}}: ViewModifier {
    // MARK: - Properties
    let parameter: {{ParameterType}}
    
    // MARK: - ViewModifier
    func body(content: Content) -> some View {
        content
            .modifier(implementation)
    }
    
    private var implementation: some ViewModifier {
        // Implement modifier logic
        EmptyModifier()
    }
}

// MARK: - View Extension
extension View {
    func {{modifierName}}(_ parameter: {{ParameterType}} = defaultValue) -> some View {
        modifier({{ModifierName}}(parameter: parameter))
    }
}

#Preview {
    Text("Preview")
        .{{modifierName}}()
}
```

### Test Class Template
Generate test class with standard patterns:

```swift
import Testing
import SwiftData
@testable import MovingBox

struct {{TestClassName}} {
    
    // MARK: - Test Setup
    private func createTestContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: {{ModelType}}.self, configurations: configuration)
        return container
    }
    
    // MARK: - Tests
    @Test("Test description")
    func testSpecificFunctionality() async throws {
        // Arrange
        let container = createTestContainer()
        let context = container.mainContext
        
        // Act
        // Perform test action
        
        // Assert
        #expect(condition == expectedValue)
    }
    
    @Test("Test error handling")
    func testErrorScenario() async throws {
        // Arrange
        // Set up error condition
        
        // Act & Assert
        await #expect(throws: {{ExpectedError}}.self) {
            // Code that should throw
        }
    }
}
```

## Usage Instructions

### 1. Specify Component Type
Choose from the available boilerplate types:
- SwiftUI View with ViewModel
- SwiftData Model
- Service Class with Protocol
- Manager (Environment Object)
- Custom View Modifier
- Test Class

### 2. Provide Component Details
Include the following information:
- **Component Name**: The name of the new component
- **Purpose**: Brief description of what it does
- **Dependencies**: Any specific dependencies needed
- **Location**: Where in the project structure it should go

### 3. Customization Parameters
Replace template placeholders:
- `{{ViewName}}`, `{{ModelName}}`, `{{ServiceName}}`, etc.
- `{{ParameterType}}`, `{{ResultType}}`, `{{DataType}}`
- Add specific properties and methods as needed

## Integration Guidelines

### Following MovingBox Patterns
- Use established naming conventions
- Follow the MVVM + Router architecture
- Integrate with existing Environment Objects
- Use OptimizedImageManager for images
- Follow error handling patterns

### Testing Integration
- Create corresponding test files
- Use in-memory SwiftData containers
- Mock external dependencies
- Follow TDD principles where applicable

### Documentation
- Add appropriate inline comments
- Update relevant CLAUDE.md files if needed
- Include usage examples in code comments
- Add to project documentation if it's a significant component

Remember to:
- Replace all template placeholders with actual names
- Add specific business logic for your use case
- Follow the existing code style and conventions
- Include appropriate error handling
- Add comprehensive tests for new components