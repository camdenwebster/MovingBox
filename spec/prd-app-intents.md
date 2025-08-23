# Product Requirements Document: App Intents Integration

## Overview
Add comprehensive App Intents support to MovingBox iOS app to enable top-tier integration with Shortcuts, Siri, and Apple Intelligence. This will allow users to manage their home inventory through voice commands, automation shortcuts, and intelligent suggestions.

## Problem Statement
Currently, MovingBox requires users to manually open the app to perform any inventory management tasks. Users cannot leverage Apple's ecosystem features like Shortcuts, Siri voice commands, or Apple Intelligence suggestions to streamline their inventory workflows.

## Success Metrics
- **Primary**: Number of App Intents executions per active user per week
- **Secondary**: User retention rate increase among users who use App Intents
- **Tertiary**: App Store rating improvement due to enhanced iOS integration
- **Technical**: All 21 defined intents successfully executable via Shortcuts and Siri

## User Stories

### As a user managing my home inventory:
- I want to quickly add items to my inventory using Siri voice commands
- I want to create Shortcuts automations for common inventory tasks
- I want to receive Apple Intelligence suggestions for inventory management
- I want to access my inventory data through other apps via Shortcuts

### As a power user:
- I want to automate photo-based item creation when I take pictures in certain locations
- I want to export my inventory data on a schedule using Shortcuts
- I want to integrate inventory updates with my home automation systems

## Requirements

### Core App Intents Categories

#### 1. Inventory Items (8 intents)
- **Create Inventory Item**: Manual creation with title (required field)
  - Input: Title (required), optional: quantity, description, location, label, price, notes
  - Output: Success confirmation, option to open item in app
  - Siri phrase: "Create inventory item [title]"

- **Create Inventory Item from Photo**: AI-powered creation from image
  - Input: Photo (camera or photo library)
  - Output: Created item details, option to open item in app
  - Integration: OpenAI Vision API for image analysis
  - Siri phrase: "Add inventory item from photo"

- **Create Inventory Item from Description**: Text-based AI creation (new feature)
  - Input: Text description of item
  - Output: Created item with AI-extrapolated details, option to open item in app
  - Integration: OpenAI text analysis for structured data extraction
  - Siri phrase: "Describe inventory item [description]"

- **Get Inventory Item**: Retrieve item details
  - Input: Item title or selection from list
  - Output: Full item details (title, quantity, location, label, price, notes, photos)
  - Siri phrase: "Get details for [item title]"

- **Update Existing Inventory Item**: Modify item properties
  - Input: Item selection, field to update, new value
  - Output: Confirmation of update
  - Siri phrase: "Update [item] [field] to [value]"

- **Delete Inventory Item**: Remove item from inventory
  - Input: Item selection, confirmation
  - Output: Deletion confirmation
  - Siri phrase: "Delete inventory item [title]"

- **Open Inventory Record**: Launch app to specific item
  - Input: Item selection
  - Output: App opens to InventoryDetailView
  - Siri phrase: "Open [item title] in MovingBox"

- **Search Inventory Items**: Find items by criteria
  - Input: Search query (title, location, label)
  - Output: List of matching items
  - Siri phrase: "Find inventory items [query]"

#### 2. Locations (5 intents)
- **Create Location**: Add new inventory location
  - Input: Location name (required), optional: description, room type
  - Output: Created location confirmation
  - Siri phrase: "Create location [name]"

- **Get Location**: Retrieve location details and items
  - Input: Location name or selection
  - Output: Location details and item count
  - Siri phrase: "Get location [name]"

- **Open Location**: Launch app to location view
  - Input: Location selection
  - Output: App opens to location detail view
  - Siri phrase: "Open [location] in MovingBox"

- **Update Location**: Modify location properties
  - Input: Location selection, field to update, new value
  - Output: Confirmation of update
  - Siri phrase: "Update location [name]"

- **Delete Location**: Remove location (with item handling)
  - Input: Location selection, confirmation, action for existing items
  - Output: Deletion confirmation
  - Siri phrase: "Delete location [name]"

#### 3. Labels (4 intents)
- **Create Label**: Add new inventory label/category
  - Input: Label name (required), optional: color, description
  - Output: Created label confirmation
  - Siri phrase: "Create label [name]"

- **Get Label**: Retrieve label details and item count
  - Input: Label name or selection
  - Output: Label details and associated item count
  - Siri phrase: "Get label [name]"

- **Update Label**: Modify label properties
  - Input: Label selection, field to update, new value
  - Output: Confirmation of update
  - Siri phrase: "Update label [name]"

- **Delete Label**: Remove label (with item handling)
  - Input: Label selection, confirmation, action for existing items
  - Output: Deletion confirmation
  - Siri phrase: "Delete label [name]"

#### 4. Home Details (2 intents)
- **Get Home Details**: Retrieve home information
  - Input: None
  - Output: Home details (name, address, insurance info summary)
  - Siri phrase: "Get my home details"

- **Update Home Details**: Modify home information
  - Input: Field to update, new value
  - Output: Confirmation of update
  - Siri phrase: "Update home [field] to [value]"

#### 5. Insurance Details (2 intents)
- **Get Insurance Details**: Retrieve insurance policy information
  - Input: None or policy selection
  - Output: Insurance policy details
  - Siri phrase: "Get my insurance details"

- **Update Insurance Details**: Modify insurance information
  - Input: Field to update, new value
  - Output: Confirmation of update
  - Siri phrase: "Update insurance [field] to [value]"

#### 6. Utilities (2 intents)
- **Create CSV Backup**: Export inventory data
  - Input: Optional: specific locations/labels to include
  - Output: CSV file shared via system share sheet
  - Integration: Existing DataManager CSV export functionality
  - Siri phrase: "Export my inventory"

- **Open Camera (Add Item Flow)**: Launch camera for item creation
  - Input: None
  - Output: App opens to camera view for adding new item
  - Integration: Existing AddInventoryItemView camera flow
  - Siri phrase: "Take inventory photo"

### Technical Requirements

#### App Intents Framework Integration
- Implement App Intents framework with iOS 16+ support
- Create intent definitions with proper parameters and return types
- Implement app shortcuts provider for suggested automations
- Support for interactive widgets and Lock Screen shortcuts

#### Data Access & Security
- Ensure all intents work with SwiftData models
- Implement proper error handling for database operations
- Respect user privacy settings and permissions
- Handle app backgrounding and data access limitations

#### AI Integration
- Extend OpenAI Vision API integration for photo-based intents
- Implement new text-to-structured-data OpenAI integration for description-based creation
- Handle API rate limits and offline scenarios gracefully
- Maintain existing AI analysis patterns and error handling

#### User Experience
- Provide clear confirmation messages for all actions
- Implement proper parameter validation and user-friendly error messages
- Support undo functionality where appropriate
- Maintain consistency with existing app UI/UX patterns

#### Performance & Reliability
- Optimize intent execution time (target: <3 seconds for most operations)
- Implement proper background task handling
- Cache frequently accessed data for faster intent responses
- Handle memory constraints in background execution

### Non-Goals
- Web-based or cross-platform intent execution
- Complex multi-step workflow automation (beyond basic shortcuts)
- Integration with third-party inventory management systems
- Real-time synchronization during intent execution

### Success Criteria
- All 21 intents successfully implemented and tested
- Intents discoverable and executable via Shortcuts app
- Siri voice recognition working for all defined phrases
- Apple Intelligence suggestions appearing appropriately
- Intent execution time under 3 seconds for 95% of operations
- Zero crashes during intent execution
- Proper error handling with user-friendly messages

### Dependencies
- iOS 16+ for App Intents framework support
- Existing OpenAI Vision API integration
- SwiftData models and OptimizedImageManager
- DataManager CSV export functionality
- Existing camera and photo management systems

### Risks and Mitigations
- **Risk**: AI-based intents may be slow or unreliable
  - **Mitigation**: Implement timeout handling and fallback options

- **Risk**: Background execution limitations may affect intent performance
  - **Mitigation**: Design intents for quick execution, cache necessary data

- **Risk**: User privacy concerns with data access from intents
  - **Mitigation**: Clear documentation of data usage, minimal necessary permissions

### Implementation Phases

#### Phase 1: Framework Setup and Basic Intents
- App Intents framework integration
- Basic CRUD intents for items, locations, labels
- Core infrastructure and error handling

#### Phase 2: Advanced Features
- AI-powered intents (photo and description-based creation)
- Home and insurance detail intents
- Utility intents (CSV export, camera launch)

#### Phase 3: Polish and Optimization
- Performance optimization
- Enhanced error handling and user feedback
- Testing and bug fixes
- Documentation and user education

### Testing Strategy
- Unit tests for all intent implementations
- Integration tests with SwiftData and AI services
- Siri and Shortcuts functionality testing
- Performance testing under various conditions
- Accessibility testing for voice commands

### Documentation Requirements
- User-facing documentation for available intents and Siri phrases
- Developer documentation for intent architecture
- Troubleshooting guide for common issues
- App Store description updates highlighting Shortcuts integration