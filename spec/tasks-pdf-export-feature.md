# PDF Export Feature - Technical Task List

Based on the PRD and architecture outlined in issue #184, this document breaks down the implementation into detailed, actionable tasks.

## Overview
Implement professional PDF report generation with background processing, SwiftData integration, and iCloud sync capabilities.

## Phase 1: Core Data Models & Infrastructure

### Task 1.1: Create GeneratedReport SwiftData Model
**Estimated Time**: 2-3 hours  
**Priority**: High  
**Dependencies**: None  

- [ ] Create `GeneratedReport.swift` in `/Models/` directory
- [ ] Implement SwiftData model with properties:
  - `id: UUID` - Unique identifier
  - `title: String` - Report title
  - `dateCreated: Date` - Creation timestamp
  - `itemCount: Int` - Number of items in report
  - `status: ReportStatus` - Generation status enum
  - `fileURL: URL?` - Optional file location
  - `fileSize: Int` - PDF file size in bytes
  - `homeId: UUID` - Reference to associated home
- [ ] Define `ReportStatus` enum: `.generating`, `.completed`, `.failed`
- [ ] Add computed properties for display formatting
- [ ] Write unit tests for model initialization and relationships

### Task 1.2: Integrate Report Model with SwiftData Container
**Estimated Time**: 1-2 hours  
**Priority**: High  
**Dependencies**: Task 1.1  

- [ ] Add `GeneratedReport` to ModelContainer schema in `ModelContainerManager.swift`
- [ ] Update any existing migration logic if needed
- [ ] Test model persistence and querying
- [ ] Verify iCloud sync functionality for metadata

### Task 1.3: Create Report File Management Service
**Estimated Time**: 3-4 hours  
**Priority**: High  
**Dependencies**: None  

- [ ] Create `ReportFileManager.swift` in `/Services/` directory
- [ ] Implement file storage in Documents directory: `/Documents/Reports/{reportId}.pdf`
- [ ] Add methods:
  - `savePDFData(_:for:) throws -> URL` - Save PDF to disk
  - `loadPDFData(for:) throws -> Data` - Load existing PDF
  - `deletePDF(for:) throws` - Remove PDF file
  - `getPDFURL(for:) -> URL` - Get file URL for sharing
- [ ] Handle file system errors gracefully
- [ ] Implement automatic cleanup for orphaned files
- [ ] Write unit tests for all file operations

## Phase 2: PDF Generation Engine

### Task 2.1: Create PDF Page Layout Views
**Estimated Time**: 6-8 hours  
**Priority**: High  
**Dependencies**: None  

- [ ] Create `PDFPageViews/` subdirectory in `/Views/Other/`
- [ ] Implement `ReportCoverPageView.swift`:
  - Home details (name, address, description)
  - Report generation date
  - Total item count and value summary
  - Professional letterhead/branding
- [ ] Implement `ReportTableOfContentsView.swift`:
  - List all locations with page numbers
  - Summary statistics section
  - Professional page numbering
- [ ] Implement `ReportLocationCoverView.swift`:
  - Location name and description
  - Item count and total value for location
  - Navigation breadcrumb
- [ ] Implement `ReportItemPageView.swift`:
  - Display 10-15 items per page in grid layout
  - Item photos (scaled appropriately)
  - Item details: name, value, description, labels
  - Location context
- [ ] All views designed for 8.5" x 11" portrait (612x792 points)
- [ ] Implement consistent styling and typography

### Task 2.2: Create PDF Generator Actor
**Estimated Time**: 8-10 hours  
**Priority**: High  
**Dependencies**: Task 2.1  

- [ ] Create `PDFGenerator.swift` actor in `/Services/` directory
- [ ] Implement core methods:
  - `generatePDF(for items: [InventoryItem]) async throws -> Data`
  - `generateCoverPage(for home: Home) async -> Data`
  - `generateTableOfContents(locations:) async -> Data`
  - `generateLocationPages(for location: InventoryLocation) async -> Data`
  - `generateItemPages(items: [InventoryItem]) async -> Data`
- [ ] Use ImageRenderer for SwiftUI-to-PDF conversion
- [ ] Implement memory-efficient multi-page rendering
- [ ] Handle image loading and scaling
- [ ] Add comprehensive error handling
- [ ] Optimize for large inventories (pagination strategy)
- [ ] Write unit tests for PDF generation logic

### Task 2.3: Create Report Coordination Service
**Estimated Time**: 4-5 hours  
**Priority**: High  
**Dependencies**: Task 1.1, Task 1.3, Task 2.2  

- [ ] Create `ReportCoordinator.swift` as @MainActor class in `/Services/`
- [ ] Implement main workflow:
  - `generateReport(for home: Home) async throws -> GeneratedReport`
  - Create placeholder report with `.generating` status
  - Dispatch PDF generation to background
  - Update report status when complete
  - Handle errors and update to `.failed` state
- [ ] Add progress tracking capabilities
- [ ] Implement local notification when complete
- [ ] Add cleanup for failed generations
- [ ] Write integration tests for full workflow

## Phase 3: User Interface Integration

### Task 3.1: Update Share Sheet in InventoryListView
**Estimated Time**: 3-4 hours  
**Priority**: High  
**Dependencies**: None  

- [ ] Modify `InventoryListView.swift` share button implementation
- [ ] Replace direct CSV export with menu options:
  - "Export CSV" (existing functionality)
  - "Generate PDF Report" (new functionality)
- [ ] Use SwiftUI Menu view for share sheet options
- [ ] Update toolbar layout and spacing
- [ ] Maintain existing CSV export behavior
- [ ] Add appropriate SF Symbols for menu items
- [ ] Test UI on different device sizes

### Task 3.2: Create Reports Management View
**Estimated Time**: 6-8 hours  
**Priority**: Medium  
**Dependencies**: Task 1.1, Task 3.1  

- [ ] Create `ReportsListView.swift` in `/Views/Settings/` directory
- [ ] Implement features:
  - List all generated reports
  - Show generation status with appropriate indicators
  - Display report metadata (date, size, item count)
  - Share functionality per report
  - Delete functionality with confirmation
- [ ] Add pull-to-refresh for status updates
- [ ] Implement empty state view
- [ ] Add navigation from InventoryListView bottom toolbar
- [ ] Handle real-time status updates during generation
- [ ] Write snapshot tests for different states

### Task 3.3: Add Report Generation Progress UI
**Estimated Time**: 3-4 hours  
**Priority**: Medium  
**Dependencies**: Task 2.3, Task 3.2  

- [ ] Create progress indicator in ReportsListView
- [ ] Show generation status with:
  - Progress spinner for generating reports
  - Success checkmark for completed reports
  - Error indicator for failed reports
- [ ] Add estimated time remaining if possible
- [ ] Implement cancellation capability
- [ ] Show local notification when generation completes
- [ ] Handle background app state during generation

## Phase 4: Integration & Polish

### Task 4.1: Add Settings and Preferences
**Estimated Time**: 2-3 hours  
**Priority**: Low  
**Dependencies**: Task 3.2  

- [ ] Add PDF report settings section in `SettingsView.swift`
- [ ] Options to configure:
  - Default report title format
  - Include/exclude certain item fields
  - Photo quality settings
  - Auto-cleanup old reports preference
- [ ] Store preferences in SettingsManager
- [ ] Apply preferences in PDF generation

### Task 4.2: Telemetry and Analytics Integration
**Estimated Time**: 1-2 hours  
**Priority**: Low  
**Dependencies**: Task 2.3  

- [ ] Add telemetry events in `TelemetryManager.swift`:
  - `pdf_report_generation_started`
  - `pdf_report_generation_completed`
  - `pdf_report_generation_failed`
  - `pdf_report_shared`
  - `pdf_report_deleted`
- [ ] Include relevant metadata (item count, file size, generation time)
- [ ] Respect user privacy settings
- [ ] Test analytics in different scenarios

### Task 4.3: Error Handling and User Feedback
**Estimated Time**: 2-3 hours  
**Priority**: High  
**Dependencies**: All previous tasks  

- [ ] Implement comprehensive error handling:
  - Network errors during image loading
  - File system errors during PDF creation
  - Memory pressure during generation
  - SwiftData persistence errors
- [ ] Add user-friendly error messages
- [ ] Implement retry mechanisms where appropriate
- [ ] Add error logging with appropriate detail level
- [ ] Test error scenarios and recovery

## Phase 5: Testing & Quality Assurance

### Task 5.1: Unit Test Coverage
**Estimated Time**: 4-6 hours  
**Priority**: High  
**Dependencies**: All implementation tasks  

- [ ] Write comprehensive unit tests for:
  - GeneratedReport model operations
  - ReportFileManager file operations
  - PDFGenerator PDF creation logic
  - ReportCoordinator workflow management
- [ ] Test edge cases:
  - Empty inventories
  - Very large inventories (1000+ items)
  - Missing images
  - Disk space limitations
- [ ] Achieve >90% code coverage for new components

### Task 5.2: Integration Testing
**Estimated Time**: 3-4 hours  
**Priority**: High  
**Dependencies**: All implementation tasks  

- [ ] Create integration tests in `MovingBoxTests/`:
  - End-to-end PDF generation workflow
  - iCloud sync for report metadata
  - Background generation with app state changes
  - Memory usage during large report generation
- [ ] Test with realistic data sets
- [ ] Verify PDF structure and content accuracy

### Task 5.3: UI Testing
**Estimated Time**: 4-5 hours  
**Priority**: High  
**Dependencies**: Task 3.1, Task 3.2  

- [ ] Create UI tests in `MovingBoxUITests/`:
  - Share sheet menu functionality
  - Report generation initiation
  - Reports list navigation and interaction
  - Sharing generated reports
- [ ] Add screen objects for new views
- [ ] Test accessibility features
- [ ] Verify proper error state handling in UI

### Task 5.4: Snapshot Testing
**Estimated Time**: 2-3 hours  
**Priority**: Medium  
**Dependencies**: Task 3.1, Task 3.2  

- [ ] Add snapshot tests for:
  - Updated InventoryListView with share menu
  - ReportsListView in different states
  - PDF page layouts (sample rendering)
- [ ] Test light and dark mode variants
- [ ] Include mock data scenarios

## Phase 6: Performance & Optimization

### Task 6.1: Performance Testing
**Estimated Time**: 3-4 hours  
**Priority**: High  
**Dependencies**: All implementation tasks  

- [ ] Profile PDF generation performance:
  - Memory usage during large report generation
  - Time to generate reports of different sizes
  - Background processing efficiency
- [ ] Test with inventories of varying sizes:
  - Small (10-50 items)
  - Medium (100-500 items)  
  - Large (1000+ items)
- [ ] Identify and optimize bottlenecks
- [ ] Ensure UI remains responsive during generation

### Task 6.2: Memory and Storage Optimization
**Estimated Time**: 2-3 hours  
**Priority**: Medium  
**Dependencies**: Task 6.1  

- [ ] Implement memory-efficient image handling
- [ ] Add automatic cleanup of old reports
- [ ] Optimize PDF compression settings
- [ ] Handle low storage scenarios gracefully
- [ ] Add storage usage monitoring

## Phase 7: Documentation & Deployment

### Task 7.1: Code Documentation
**Estimated Time**: 2-3 hours  
**Priority**: Medium  
**Dependencies**: All implementation tasks  

- [ ] Add comprehensive code documentation:
  - Public API methods with detailed comments
  - Architecture decision documentation
  - Usage examples for key components
- [ ] Update CLAUDE.md with PDF export patterns
- [ ] Document testing approaches and edge cases

### Task 7.2: User Documentation
**Estimated Time**: 1-2 hours  
**Priority**: Low  
**Dependencies**: All implementation tasks  

- [ ] Update app help content if needed
- [ ] Create feature announcement content
- [ ] Document user-facing functionality

### Task 7.3: Feature Flag and Rollout Preparation
**Estimated Time**: 1-2 hours  
**Priority**: Medium  
**Dependencies**: All implementation tasks  

- [ ] Consider adding feature flag in AppConfig
- [ ] Prepare for gradual rollout if needed
- [ ] Plan monitoring strategy for initial release
- [ ] Coordinate with subscription gating if applicable

## Summary

**Total Estimated Time**: 60-85 hours
**Critical Path**: Data Models → PDF Generation → UI Integration → Testing
**Key Risk Areas**: Memory usage with large inventories, PDF rendering performance
**Dependencies**: SwiftData, ImageRenderer (iOS 16+), iCloud Document sync

## Implementation Order Recommendation

1. **Phase 1** (Infrastructure): Establish data models and file management
2. **Phase 2** (Core Engine): Build PDF generation capabilities  
3. **Phase 3** (UI Integration): Connect to existing user interface
4. **Phase 4** (Polish): Add configuration and analytics
5. **Phase 5** (Testing): Comprehensive quality assurance
6. **Phase 6** (Performance): Optimization and profiling
7. **Phase 7** (Documentation): Final documentation and deployment prep

This phased approach allows for incremental development with early validation of core functionality.