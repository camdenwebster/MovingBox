# Product Requirements Document: Multi-Photo Camera Feature

## Introduction/Overview

This feature enables users to capture multiple photos (up to 5) of an inventory item using a custom camera interface. The interface displays thumbnails of captured photos in a horizontal scroll view below the square viewfinder, with delete functionality for each photo. All photos are automatically cropped to square (1:1) aspect ratio and analyzed together by AI to create a comprehensive item description.

**Problem Solved**: Users often need multiple angles or views of an item to properly document it for insurance or inventory purposes. A single photo may not capture important details like serial numbers, different angles, or condition details.

**Goal**: Improve inventory documentation accuracy by allowing multiple photos per item while maintaining a streamlined user experience.

## Goals

1. Allow users to capture up to 5 photos of a single inventory item
2. Provide visual feedback through thumbnail display and photo count indicators
3. Enable comprehensive AI analysis using all captured photos
4. Maintain current camera functionality (flash, zoom, camera switching)
5. Support adding additional photos to existing inventory items
6. Ensure seamless integration with existing inventory creation workflow

## User Stories

1. **As a user documenting a complex item**, I want to take multiple photos from different angles so that I can capture all important details in one inventory record.

2. **As a user photographing an item with a serial number**, I want to take one photo of the overall item and another close-up of the serial number so that all information is documented together.

3. **As a user who made a mistake**, I want to delete a photo I just took and retake it so that only my best photos are used for AI analysis.

4. **As a user with an existing inventory item**, I want to add additional photos to provide more detail so that my documentation is more comprehensive.

5. **As a user approaching the photo limit**, I want to be notified when I'm at the maximum so that I understand the system constraints.

## Functional Requirements

### Camera Interface
1. The camera view must display a square viewfinder (1:1 aspect ratio) that shows the area that will be captured
2. The system must automatically crop all captured photos to square format
3. The camera must support all existing controls: flash toggle, zoom cycling, and front/back camera switching
4. A "Done" button must be displayed in the upper right corner of the camera interface

### Photo Management
5. Captured photos must be displayed as thumbnails in a horizontal scroll view below the viewfinder
6. Each thumbnail must display a small "x" icon in the corner for deletion
7. The system must display a photo count indicator (e.g., "3/5 photos")
8. Users must be able to capture up to 5 photos maximum
9. If a user attempts to take a 6th photo, the system must display an alert explaining the limit
10. Photos must be stored in the order they are taken

### Data Storage
11. The InventoryItem model must be extended with a new property to store an array of secondary photo URLs
12. The primary photo (first photo taken) must continue to use the existing imageURL property
13. Additional photos must be stored in the new secondary photos array
14. All photos must be optimized/resized before storage (following existing image optimization patterns)

### AI Analysis
15. When "Done" is tapped, AI analysis must begin using all captured photos
16. The AI must analyze all photos together to create one comprehensive item description
17. The analysis must follow the existing ImageAnalysisView user experience pattern
18. After analysis completes, users must be navigated to the inventory detail view of the new item

### Integration with Existing Items
19. Existing inventory items must display all photos in a horizontal scroll view in the detail view
20. The final position in the photo scroll view must show a "+" button for adding additional photos
21. Tapping the "+" button must launch the multi-photo camera for existing items
22. New photos added to existing items must be appended to the secondary photos array

### Error Handling
23. The system must handle camera permission denials gracefully
24. Memory constraints must be managed by optimizing images immediately after capture
25. The system must handle cases where AI analysis fails for multiple photos

## Non-Goals (Out of Scope)

1. Video recording functionality
2. Photo editing or filtering capabilities
3. Manual photo reordering after capture
4. Manual crop adjustment - all crops are automatic
5. Photo sharing or export functionality beyond existing capabilities
6. Integration with external photo libraries during multi-capture flow
7. Live photo or burst mode capabilities
8. Advanced camera features like portrait mode or macro

## Design Considerations

- Follow the existing CustomCameraView design patterns and UI styling
- Maintain consistency with the current app's visual design language
- Ensure thumbnails are large enough to be easily tappable but small enough to show multiple photos
- The photo count indicator should be prominently displayed but not interfere with camera controls
- Horizontal scroll view should have smooth scrolling and clear visual boundaries

## Technical Considerations

- Extend the InventoryItem Core Data model to include `secondaryPhotoURLs: [String]` property
- Implement data migration for existing items (they will have empty secondary photos arrays)
- Reuse existing OptimizedImageManager for image processing and storage
- Modify the AI analysis workflow to accept multiple images in the OpenAIService
- Update the ImageAnalysisView to handle multiple photos in analysis
- Ensure memory management during multi-photo capture by processing images immediately
- Update PhotoPickerView component to support multiple photo display and management

## Success Metrics

1. **User Adoption**: 70% of new inventory items use multiple photos within 30 days of feature release
2. **AI Accuracy**: AI analysis accuracy improves by 25% for items with multiple photos compared to single photos
3. **User Satisfaction**: User feedback indicates improved inventory documentation experience
4. **Performance**: Camera interface maintains smooth 60fps performance during multi-photo capture
5. **Error Rate**: Less than 5% of multi-photo sessions result in errors or crashes

## Open Questions

1. Should there be a minimum number of photos required before AI analysis can begin?
2. How should we handle very poor quality photos that might negatively impact AI analysis?
3. Should users be able to designate which photo should be the "primary" photo for list view display?
4. Do we need any visual indicators to help users understand what makes a good additional photo (e.g., "Try capturing the serial number")?
5. Should the thumbnail scroll view have any ordering indicators (like 1, 2, 3) to show the sequence?