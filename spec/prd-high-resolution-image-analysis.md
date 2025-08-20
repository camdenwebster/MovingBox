# Product Requirements Document: High Resolution Image Analysis for Pro Users

## Introduction/Overview

This feature enhances the AI image analysis capabilities for Pro users by implementing high-resolution image processing, upgraded AI models, and improved analysis parameters. Non-Pro users will continue to use the existing analysis system while Pro users get access to superior image analysis quality and unlimited usage.

**Problem Solved**: Current image analysis is limited to 512x512 resolution with basic detail parameters, resulting in less accurate AI analysis. Pro users want higher quality analysis that can better identify details, serial numbers, and product information from images.

**Goal**: Provide Pro users with premium image analysis capabilities using high-resolution processing and advanced AI models while maintaining fast analysis for users who prefer speed over quality.

## Goals

1. Implement high-resolution image processing (1250x1250px) for Pro users
2. Upgrade Pro users to gpt-5-mini model with "high" detail parameter
3. Remove the 50 AI analysis limit for all users (not just Pro)
4. Add a Pro-only settings toggle to disable high quality mode when desired
5. Track AI analysis usage per item via TelemetryDeck for analytics
6. Follow the latest OpenAI Vision API Responses format
7. Maintain backward compatibility with existing non-Pro analysis workflow

## User Stories

1. **As a Pro user documenting valuable items**, I want high-resolution AI analysis so that small details like serial numbers and model information are accurately detected.

2. **As a Pro user with good internet connection**, I want the highest quality analysis by default so that I get the most comprehensive item descriptions.

3. **As a Pro user with slower internet**, I want the option to disable high quality mode so that I can get faster analysis when needed.

4. **As a non-Pro user**, I want unlimited AI analyses so that I'm not restricted by the 50-scan limit when documenting my inventory.

5. **As an app developer**, I want to track analysis usage patterns so that I can understand how users interact with the AI features and optimize the service.

6. **As a non-Pro user**, I should not see options for features I cannot use, but I should be aware that higher quality analysis is available with Pro.

## Functional Requirements

### Image Processing
1. Pro users' images must be cropped to square format and resized to 1250x1250 pixels before analysis
2. Non-Pro users continue to use existing 512x512 pixel processing
3. Image optimization must occur in the `OptimizedImageManager` service
4. Both user types maintain existing image quality for storage purposes

### AI Model Configuration
5. Pro users must use the `gpt-5-mini` model for analysis
6. Non-Pro users continue using the existing `gpt-5` model
7. Pro users must have the `detail` parameter set to "high" 
8. Non-Pro users continue using "low" detail parameter
9. Model selection must be determined by the user's Pro status from `AppConfig.shared.isPro`

### Settings UI Updates
10. The Settings view must remove the AI usage progress indicator section for all users
11. Pro users must see a new "High Quality Analysis" toggle setting (enabled by default)
12. The toggle must be visible but disabled for non-Pro users with explanatory text
13. The toggle state must be stored in `SettingsManager` and persist across app launches
14. When disabled, Pro users should use the same parameters as non-Pro users

### API Format Compliance
15. The OpenAI service must follow the up-to-date "Responses" API format as specified in the OpenAI documentation
16. Request structure must be validated against the latest API specification
17. Error handling must accommodate any API format changes

### Analytics Integration
18. Each AI analysis must be tracked via TelemetryDeck with the following metadata:
    - User type (Pro/non-Pro)
    - Image resolution used (1250x1250 or 512x512)
    - Model used (gpt-5-mini or gpt-5)
    - Detail level (high or low)
    - Item ID to detect multiple analyses of the same item
    - Analysis success/failure status
19. Analytics must not include any personally identifiable information

### Error Handling & Performance
20. High-resolution analysis requests must include appropriate timeout handling
21. If high-resolution analysis fails, the system should gracefully fallback to standard resolution
22. Memory usage must be monitored to prevent crashes with large images
23. Request size limits must be enforced (max 20MB as per current implementation)

## Non-Goals (Out of Scope)

1. Custom resolution selection beyond the two defined tiers
2. Manual model selection in the UI
3. Batch analysis of multiple items simultaneously
4. Real-time analysis preview during image capture
5. Analysis result comparison between quality levels
6. Integration with third-party AI services
7. Offline analysis capabilities
8. Analysis result caching or storage beyond current patterns

## Technical Implementation Details

### Settings Manager Updates
- Add `highQualityAnalysisEnabled: Bool` property (default: true for Pro, false for non-Pro)
- Implement Pro-status-aware default values
- Add UserDefaults key for persistence

### OpenAI Service Modifications
- Update image preprocessing logic to check Pro status and quality settings
- Modify model selection logic based on user tier and preferences
- Update request payload structure for new API format
- Implement enhanced error handling for high-resolution requests

### UI Components
- Remove AI usage progress section from SettingsView
- Add new toggle row for high quality analysis
- Implement Pro status checking for toggle availability
- Add explanatory text for non-Pro users

### Analytics Integration
- Extend TelemetryManager with new analysis tracking methods
- Create analytics event structure for AI analysis metadata
- Implement item-level analysis tracking

### Image Processing Pipeline
- Update OptimizedImageManager to support dual resolution modes
- Implement Pro status checking in image processing workflow
- Maintain existing image storage patterns

## Success Metrics

1. **Analysis Quality**: 40% improvement in AI accuracy for detecting serial numbers and model information for Pro users
2. **User Adoption**: 80% of Pro users utilize high-resolution analysis within 30 days
3. **Performance**: High-resolution analysis completes within 15 seconds for 95% of requests
4. **Error Rate**: Less than 3% failure rate for high-resolution analysis requests
5. **User Satisfaction**: Pro users report improved analysis quality in feedback surveys
6. **Usage Analytics**: Clear differentiation between Pro and non-Pro usage patterns in TelemetryDeck data

## Open Questions

1. Should we implement progressive image quality (automatically downgrade if high-res fails)?
2. Do we need to notify users when they're using reduced quality mode due to the toggle being off?
3. Should the high quality toggle be part of the main settings or buried in an advanced section?
4. How should we handle mixed-quality analysis for items with multiple photos (from the multi-photo feature)?
5. Should we provide any indication in the UI when high-resolution analysis is in progress vs standard?
6. Do we need separate analytics for the multi-photo feature when combined with high-resolution?

## Dependencies

- OpenAI Vision API access to gpt-5-mini model
- TelemetryDeck analytics service
- RevenueCat Pro status verification
- Existing OptimizedImageManager service
- Current SettingsManager infrastructure

## Risk Assessment

**Technical Risks:**
- Higher resolution images may cause memory issues on older devices
- Increased API costs for high-resolution analysis
- Potential API rate limiting with premium models

**Mitigation Strategies:**
- Implement memory monitoring and fallback mechanisms
- Monitor API usage and costs closely
- Implement proper request queuing and retry logic

**User Experience Risks:**
- Longer analysis times may frustrate users expecting instant results
- Non-Pro users may feel excluded from quality improvements

**Mitigation Strategies:**
- Provide clear progress indicators for longer analysis
- Emphasize the speed benefit of standard quality for non-Pro users
- Ensure the Pro upgrade value proposition is clear