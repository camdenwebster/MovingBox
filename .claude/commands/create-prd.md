# Create Product Requirements Document (PRD)

Generate a detailed Product Requirements Document (PRD) for a new MovingBox feature or product enhancement: $ARGUMENTS

## Process Overview

### 1. Initial Analysis
Before creating the PRD, analyze the feature request in the context of MovingBox's architecture and user base:
- **Current State**: Understand how this fits with existing inventory management features
- **User Impact**: Consider impact on both free and pro users
- **Technical Feasibility**: Assess compatibility with SwiftUI, SwiftData, and existing services

### 2. Clarifying Questions Phase
**DO NOT start writing the PRD immediately.** First, ask targeted clarifying questions to gather sufficient detail. Adapt questions based on the specific request, but consider these areas:

#### Problem Definition
- What specific problem does this feature solve for MovingBox users?
- How does this align with our core mission of AI-powered inventory management?
- What user pain points have been identified that led to this request?

#### Target Users
- Is this primarily for free users, pro users, or both?
- What user personas would benefit most from this feature?
- How does this fit into typical user workflows (onboarding, item management, etc.)?

#### Functional Requirements
- What are the core actions users should be able to perform?
- How should this integrate with existing features (camera, AI analysis, locations, labels)?
- What data needs to be captured, processed, or displayed?

#### User Stories
- Can you provide specific user stories in the format: "As a [user type], I want to [action] so that [benefit]"?
- What are the primary and secondary use cases?
- How should edge cases be handled?

#### Success Criteria
- How will we measure the success of this feature?
- What metrics should improve (user engagement, retention, AI usage, etc.)?
- What constitutes a "successful" implementation?

#### Scope and Boundaries
- What should this feature NOT do (non-goals)?
- Are there any technical constraints or limitations to consider?
- What's the minimum viable version vs. future enhancements?

#### MovingBox-Specific Considerations
- How does this integrate with OpenAI Vision API workflows?
- Should this be gated behind RevenueCat pro subscription?
- How does this affect SwiftData models and CloudKit sync?
- What TelemetryDeck events should be tracked?
- How does this impact the onboarding flow?

#### Design and UX
- Are there existing UI patterns in MovingBox this should follow?
- Should this integrate with the Router navigation system?
- Any specific accessibility requirements?
- How should this work across iPhone and iPad?

### 3. PRD Generation
After gathering clarifying information, generate a comprehensive PRD using the structure below.

### 4. Document Saving
Save the completed PRD as `prd-[feature-name].md` in the project root directory.

## PRD Structure for MovingBox

### 1. Executive Summary
- **Feature Name**: Clear, descriptive name
- **Problem Statement**: What user problem this solves
- **Solution Overview**: High-level description of the proposed solution
- **Success Metrics**: Key measurements of success

### 2. Goals and Objectives
- **Primary Goals**: Main objectives (3-5 maximum)
- **Secondary Goals**: Additional benefits or outcomes
- **Key Results**: Measurable outcomes that define success

### 3. User Stories and Use Cases
- **Primary User Stories**: Core user narratives with clear benefits
- **Secondary Use Cases**: Additional scenarios and edge cases
- **User Journey**: How this fits into existing app workflows

### 4. Functional Requirements
Number each requirement clearly for developer reference:

#### Core Functionality
1. **[FR-001]** System must allow users to...
2. **[FR-002]** System must integrate with...
3. **[FR-003]** System must validate...

#### Integration Requirements
- **AI Integration**: How this uses OpenAI Vision API
- **Subscription Logic**: Free vs pro feature distinctions
- **Data Layer**: SwiftData model requirements
- **Navigation**: Router integration needs

#### Platform Requirements
- **iOS Compatibility**: Minimum iOS version support
- **Device Support**: iPhone and iPad considerations
- **Accessibility**: Required accessibility features
- **Localization**: Multi-language support needs

### 5. Non-Functional Requirements
- **Performance**: Response time, memory usage, battery impact
- **Security**: Data protection and privacy requirements
- **Reliability**: Error handling and recovery expectations
- **Scalability**: How this handles growth in usage

### 6. Technical Considerations
- **Architecture Impact**: How this fits MVVM + Router pattern
- **SwiftData Changes**: Model additions or modifications needed
- **Service Dependencies**: New or modified services required
- **Third-Party Integration**: OpenAI, RevenueCat, CloudKit, TelemetryDeck

### 7. Design and User Experience
- **User Interface**: Key UI components and flows
- **Navigation**: How users access this feature
- **Information Architecture**: Data organization and presentation
- **Interaction Design**: Key user interactions and feedback

### 8. Non-Goals (Out of Scope)
Clearly define what this feature will NOT include:
- Features explicitly excluded from this version
- Future considerations for later releases
- Technical limitations accepted for this iteration

### 9. Success Metrics and KPIs
- **Usage Metrics**: How feature adoption will be measured
- **Business Metrics**: Impact on subscriptions, retention, etc.
- **Technical Metrics**: Performance and reliability measurements
- **User Experience Metrics**: User satisfaction and workflow efficiency

### 10. Implementation Phases
Break down development into manageable phases:
- **Phase 1**: Core functionality (MVP)
- **Phase 2**: Enhanced features and optimizations
- **Phase 3**: Advanced capabilities and integrations

### 11. Risk Assessment
- **Technical Risks**: Implementation challenges and mitigation strategies
- **Business Risks**: Market or user adoption concerns
- **Timeline Risks**: Factors that could impact delivery schedule

### 12. Dependencies and Assumptions
- **Technical Dependencies**: Required services, frameworks, or APIs
- **Business Assumptions**: User behavior and market assumptions
- **Resource Assumptions**: Development time and expertise required

### 13. Testing Strategy
- **Unit Testing**: Core business logic validation
- **Integration Testing**: Service and component interaction testing
- **UI Testing**: User workflow and accessibility testing
- **Performance Testing**: Memory, speed, and reliability testing

### 14. Analytics and Monitoring
- **TelemetryDeck Events**: What user actions to track
- **Performance Monitoring**: Key metrics to monitor in production
- **Error Tracking**: Critical error scenarios to monitor
- **User Feedback**: How to collect and analyze user feedback

### 15. Open Questions and Next Steps
- **Unresolved Questions**: Items requiring further research or decision
- **Decision Points**: Key choices that need stakeholder input
- **Next Actions**: Immediate steps to move forward

## Guidelines for PRD Quality

### For Junior Developers
- Use clear, unambiguous language
- Provide specific examples where helpful
- Reference existing MovingBox patterns and components
- Include relevant code references when appropriate

### MovingBox-Specific Context
- Consider the AI-powered inventory management core mission
- Account for the freemium subscription model
- Reference existing UI patterns and navigation flows
- Consider impact on existing user workflows

### Documentation Standards
- Use proper Markdown formatting
- Include relevant diagrams or mockups if needed
- Reference related documentation and resources
- Maintain consistency with existing project documentation

## Process Completion

1. **Ask Clarifying Questions**: Gather all necessary information
2. **Generate Complete PRD**: Follow the structure above
3. **Save Document**: Store as `prd-[feature-name].md` in project root
4. **Reference Integration**: Note how this relates to `/feature` command for implementation

Remember: The PRD serves as the bridge between product vision and technical implementation. It should provide enough detail for developers to understand requirements while remaining focused on "what" and "why" rather than "how."

## Integration with Development Workflow

This PRD will serve as input for the `/feature` command when moving to implementation planning. The PRD defines WHAT to build, while `/feature` will determine HOW to build it within MovingBox's architecture.

**Next Steps After PRD Completion:**
1. Review and approve PRD with stakeholders
2. Use `/feature` command with PRD as input for technical planning
3. Proceed with implementation following established development workflow