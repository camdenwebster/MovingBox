# Software Development Lifecycle (SDLC) Guide for MovingBox

Complete guide for using Claude Code personas and slash commands throughout the entire software development lifecycle for MovingBox iOS development.

## Overview

This guide outlines how to use specialized Claude instances (personas) and custom slash commands to manage the complete software development lifecycle, from initial feature concept to production deployment.

## SDLC Workflow Overview

```
1. Product Planning    → Product Manager Claude + /create-prd
2. Technical Planning  → Architect Claude + /feature  
3. Task Planning      → Project Manager Claude + /create-tasks
4. Implementation     → Developer Claude + /process-tasks
5. Code Review        → Code Review Claude + /review-pr
6. Quality Assurance  → QA Claude + /test + /unittest
7. UI/UX Validation   → UX Designer Claude + visual verification
8. Deployment        → DevOps processes + monitoring
```

## Phase 1: Product Planning (Product Manager Claude)

### Objective
Define WHAT to build based on user needs and business goals.

### Process
1. **Start New Claude Session** (or use `/clear` to reset context)
2. **Set Product Manager Context**: 
   ```
   You are acting as a Product Manager for MovingBox, an AI-powered inventory management iOS app. Focus on user needs, business value, and clear requirements definition.
   ```

3. **Use `/create-prd` Command**:
   ```
   /create-prd [Feature description or user request]
   ```

4. **Follow PRD Process**:
   - Answer clarifying questions about user problems and business goals
   - Define success metrics and user stories
   - Establish scope and non-goals
   - Consider MovingBox-specific aspects (AI integration, subscription model)

### Deliverables
- **PRD Document**: `prd-[feature-name].md` with comprehensive requirements
- **Success Metrics**: Clear KPIs and measurement criteria
- **User Stories**: Detailed user narratives and acceptance criteria

### Example Session
```
User: "We need to add bulk photo analysis for users who have many items to catalog"

Product Manager Claude: I'll help create a PRD for bulk photo analysis. Let me ask some clarifying questions:

1. What specific problem does this solve for MovingBox users?
2. How many photos should users be able to process at once?
3. Should this be a pro feature or available to all users?
[... continues with PRD creation process]
```

## Phase 2: Technical Planning (Architect Claude)

### Objective
Define HOW to build the feature within MovingBox's architecture.

### Process
1. **Start New Claude Session** (important for objective technical perspective)
2. **Set Architect Context**:
   ```
   You are acting as a Senior iOS Architect for MovingBox. Your focus is on technical architecture, integration patterns, and ensuring the solution fits well with the existing SwiftUI + SwiftData + Router architecture.
   ```

3. **Provide PRD Context**: Share or reference the completed PRD
4. **Use `/feature` Command**:
   ```
   /feature Implement bulk photo analysis based on prd-bulk-photo-analysis.md
   ```

5. **Review and Approve Plan**: 
   - Evaluate technical approach and architecture decisions
   - Consider performance, security, and scalability implications
   - Ensure integration with existing services (OpenAI, RevenueCat, etc.)

### Deliverables
- **Technical Architecture**: Detailed implementation strategy
- **Integration Plan**: How feature connects with existing systems
- **Performance Considerations**: Memory, processing, and UX implications
- **Risk Assessment**: Technical challenges and mitigation strategies

### Example Session
```
User: /feature Implement bulk photo analysis based on prd-bulk-photo-analysis.md

Architect Claude: I'll analyze the MovingBox codebase and create a technical implementation plan for bulk photo analysis.

[Explores codebase, reviews existing patterns]

## Technical Implementation Plan

### Architecture Integration
- Extend OptimizedImageManager for bulk processing
- Create BatchAnalysisService for coordinating multiple AI requests
- Integrate with existing Router navigation patterns
[... continues with detailed technical planning]
```

## Phase 3: Task Planning (Project Manager Claude)

### Objective  
Break down the technical plan into actionable development tasks.

### Process
1. **Continue with Architect Claude** OR **Start New Session** if you want fresh perspective
2. **Set Project Manager Context**:
   ```
   You are acting as a Technical Project Manager for MovingBox. Your focus is on breaking down technical plans into clear, actionable tasks that developers can implement step-by-step.
   ```

3. **Provide Both PRD and Feature Plan**: Reference both previous documents
4. **Use `/create-tasks` Command**:
   ```
   /create-tasks Based on prd-bulk-photo-analysis.md and the technical feature plan
   ```

5. **Review Task Breakdown**:
   - Approve high-level task categories
   - Respond with "Go" to generate detailed sub-tasks
   - Validate that tasks are appropriately sized and sequenced

### Deliverables
- **Implementation Task List**: `tasks-[feature-name].md` with detailed sub-tasks
- **File Specifications**: Exact files to create/modify
- **Testing Strategy**: Specific test requirements
- **Quality Gates**: Checkpoints and validation criteria

### Example Session
```
User: /create-tasks Based on prd-bulk-photo-analysis.md and the technical feature plan

Project Manager Claude: I'll create a detailed task list based on the PRD and technical architecture.

High-level tasks identified:
1.0 SwiftUI View Implementation
2.0 Batch Processing Service
3.0 AI Integration Enhancement  
4.0 Navigation and Routing
5.0 Testing Implementation
6.0 Integration and Polish
7.0 Documentation and Deployment

Ready to generate detailed sub-tasks? Respond with 'Go' to proceed.

User: Go

[Continues with detailed sub-task breakdown]
```

## Phase 4: Implementation (Developer Claude)

### Objective
Implement the feature following the detailed task list.

### Process
1. **Use Primary Claude Code Session** (your main development environment)
2. **Set Developer Context**:
   ```
   You are acting as a Senior iOS Developer implementing features for MovingBox. Follow established patterns, write comprehensive tests, and maintain high code quality standards.
   ```

3. **Use `/process-tasks` Command**:
   ```
   /process-tasks tasks-bulk-photo-analysis.md
   ```

4. **Follow Implementation Protocol**:
   - Implement one sub-task at a time
   - Wait for approval before proceeding to next sub-task
   - Run tests after each significant implementation
   - Update task list and documentation as you progress

### Deliverables
- **Working Feature**: Fully implemented and tested functionality
- **Test Coverage**: Unit, integration, and UI tests
- **Updated Documentation**: Code comments and project documentation
- **Completed Task List**: All tasks marked as complete

### Example Session
```
User: /process-tasks tasks-bulk-photo-analysis.md

Developer Claude: I'll implement the bulk photo analysis feature following the task list.

Current position: Starting sub-task 1.1 - Create BatchAnalysisView.swift in Views/Items/ directory

This involves creating the main SwiftUI view for bulk photo selection and analysis.
Should I proceed? (yes/y to continue)

User: yes

[Implements the view, runs tests, updates task list]

✅ Completed sub-task 1.1: Create BatchAnalysisView.swift
- Created: MovingBox/Views/Items/BatchAnalysisView.swift
- Tests: View builds successfully, preview works
- Updated task list: Marked 1.1 as complete

Ready to proceed to sub-task 1.2: Implement basic view structure following MovingBox patterns? (yes/y to continue)
```

## Phase 5: Code Review (Code Review Claude)

### Objective
Ensure code quality, security, and adherence to MovingBox standards.

### Process
1. **Start Fresh Claude Session** (important for objective review)
2. **Set Code Review Context**:
   ```
   You are acting as a Senior Code Reviewer for MovingBox. Focus on code quality, security, performance, and adherence to iOS and MovingBox-specific best practices.
   ```

3. **Create Pull Request** (if using Git workflow)
4. **Use `/review-pr` Command**:
   ```
   /review-pr #123
   ```
   OR manually provide code for review

5. **Address Review Feedback**:
   - Implement suggested improvements
   - Fix identified issues
   - Update tests as needed

### Deliverables
- **Code Review Report**: Detailed feedback on implementation
- **Quality Assessment**: Security, performance, and maintainability evaluation
- **Improvement Recommendations**: Specific suggestions for enhancement

### Example Session
```
User: /review-pr #123

Code Review Claude: I'll review the bulk photo analysis pull request for code quality and MovingBox standards.

[Fetches PR details, analyzes changes]

## Code Review Summary

### Overall Assessment: APPROVE with minor suggestions

### Strengths:
- Follows established SwiftUI patterns
- Proper error handling implementation
- Comprehensive test coverage

### Suggestions:
1. Consider extracting magic numbers into constants
2. Add accessibility labels for new UI components
3. Minor performance optimization opportunity in batch processing

[Continues with detailed review feedback]
```

## Phase 6: Quality Assurance (QA Claude)

### Objective
Comprehensive testing and quality validation.

### Process
1. **Start New Claude Session** OR **Continue with Developer Claude**
2. **Set QA Context**:
   ```
   You are acting as a QA Engineer for MovingBox. Focus on comprehensive testing, edge case identification, and ensuring the feature works correctly across different scenarios.
   ```

3. **Use Testing Commands**:
   ```
   /test all
   /unittest [specific functionality to test]
   ```

4. **Execute Comprehensive Testing**:
   - Run all test suites (unit, integration, UI, snapshot)
   - Test on different devices and orientations
   - Verify edge cases and error scenarios
   - Test with different data states

### Deliverables
- **Test Results**: Comprehensive test execution results
- **Bug Reports**: Any issues identified during testing
- **Test Coverage Report**: Coverage analysis and gaps
- **Quality Sign-off**: Approval for production deployment

### Example Session
```
User: /test all

QA Claude: I'll run the complete test suite for MovingBox with the new bulk photo analysis feature.

[Runs all test commands]

## Test Results Summary

✅ Unit Tests: 127/127 passed
✅ Integration Tests: 23/23 passed  
✅ UI Tests: 34/34 passed
✅ Snapshot Tests: 45/45 passed

## Device Testing
✅ iPhone 16 Pro: All tests passed
✅ iPhone 14 Pro: All tests passed
✅ iPad Pro: All tests passed

## Edge Case Testing
✅ Empty photo selection: Handled correctly
✅ Network failure during AI analysis: Proper error recovery
✅ Maximum photo limit: Enforced appropriately

Feature is ready for production deployment! 🎉
```

## Phase 7: UI/UX Validation (UX Designer Claude)

### Objective
Ensure visual design quality and user experience consistency.

### Process
1. **Start New Claude Session** OR **Use iOS UX Designer Agent**
2. **Set UX Designer Context**:
   ```
   You are acting as a UX Designer for MovingBox. Focus on visual consistency, user experience quality, and ensuring the implementation matches design specifications.
   ```

3. **Visual Verification**:
   - Take screenshots using iOS Simulator MCP integration
   - Compare with design specifications
   - Test light/dark mode appearance
   - Verify accessibility features

4. **User Experience Testing**:
   - Walk through user workflows
   - Identify any UX friction points
   - Validate interaction patterns
   - Ensure consistency with existing app patterns

### Deliverables
- **Visual Validation Report**: Screenshot comparison and design compliance
- **UX Assessment**: User experience quality evaluation
- **Accessibility Audit**: Compliance with accessibility standards
- **Design Sign-off**: Approval for visual and UX quality

### Example Session
```
User: Please validate the UX for the new bulk photo analysis feature

UX Designer Claude: I'll perform a comprehensive UX validation of the bulk photo analysis feature.

[Takes screenshots, analyzes user flows]

## UX Validation Report

### Visual Consistency: ✅ APPROVED
- Follows MovingBox design system
- Proper use of colors and typography
- Consistent button styles and spacing

### User Experience: ✅ APPROVED  
- Intuitive photo selection flow
- Clear progress indicators during processing
- Appropriate error messaging

### Accessibility: ✅ APPROVED
- All interactive elements have proper labels
- Supports VoiceOver navigation
- Adequate color contrast ratios

Feature meets UX standards for production release! 🎨
```

## Phase 8: Deployment and Monitoring

### Objective
Deploy feature and monitor production performance.

### Process
1. **Final Build Verification**:
   ```
   /build release
   ```

2. **Production Deployment**:
   - Follow established deployment procedures
   - Monitor app performance and crash reports
   - Track feature usage analytics via TelemetryDeck

3. **Post-Deployment Monitoring**:
   - Monitor error rates and performance metrics
   - Collect user feedback
   - Plan iterations based on real-world usage

## Multi-Claude Strategy Best Practices

### Context Management
- **Start fresh sessions** for different roles to maintain objectivity
- **Use `/clear`** when switching contexts within same session
- **Document handoffs** between phases with clear context

### Information Flow
- **Save deliverables** from each phase (PRD, plans, task lists)
- **Reference previous work** when starting new phases
- **Maintain traceability** from requirements through implementation

### Quality Gates
- **Don't skip phases** - each provides valuable perspective
- **Validate deliverables** before proceeding to next phase
- **Address feedback** from review phases before deployment

## Workflow Variations

### Small Features/Bug Fixes
```
1. Developer Claude + /fix [issue]
2. Code Review Claude + /review-pr
3. QA validation
```

### Emergency Hotfixes
```
1. Developer Claude + /fix [critical issue]
2. Immediate testing and deployment
3. Post-deployment review
```

### Major Features
```
Full 8-phase process with additional:
- Stakeholder reviews after each phase
- Prototype validation
- Beta testing feedback integration
```

## Success Metrics

### Process Quality
- **Requirements Traceability**: All implemented features trace back to PRD requirements
- **Test Coverage**: Comprehensive testing at all levels
- **Code Quality**: Consistent adherence to MovingBox patterns
- **Documentation**: Complete and current documentation

### Delivery Quality
- **Bug Rate**: Low defect rate in production
- **Performance**: Features meet performance expectations
- **User Satisfaction**: Positive user feedback and adoption
- **Maintainability**: Code is easy to understand and modify

## Troubleshooting Common Issues

### Context Loss Between Phases
**Problem**: Claude forgets previous context when switching roles
**Solution**: 
- Save deliverables as files and reference them
- Provide clear context setting at start of each phase
- Use the project's CLAUDE.md files for consistent context

### Scope Creep During Implementation
**Problem**: Feature grows beyond original requirements
**Solution**:
- Refer back to PRD for scope validation
- Use "non-goals" section to stay focused
- Address new requirements through formal change process

### Quality Issues During Review
**Problem**: Code doesn't meet standards during review phase
**Solution**:
- Return to Developer Claude with specific feedback
- Update implementation following review guidelines
- Re-run quality assurance validation

### Integration Problems
**Problem**: Feature doesn't integrate well with existing systems
**Solution**:
- Return to Architect Claude for integration planning
- Review existing CLAUDE.md files for integration patterns
- Test integration points more thoroughly

## Conclusion

This SDLC approach provides a comprehensive, quality-focused development process that leverages Claude Code's capabilities while maintaining MovingBox's high standards for code quality, user experience, and system reliability. By following this workflow, teams can deliver features that are well-planned, properly implemented, thoroughly tested, and ready for production use.

The key to success is maintaining discipline in following the process, leveraging the strengths of each specialized Claude persona, and using the custom slash commands to maintain consistency and quality throughout the development lifecycle.