## ADDED Requirements

### Requirement: Import Loading UI Avoids Ad Hoc Debug Printing

The import loading experience MUST NOT emit ad hoc debug `print(...)` statements during normal state transitions or user interactions.

#### Scenario: Loading state is shown

- **WHEN** `ImportLoadingView` appears in loading state
- **THEN** the view renders progress messaging and progress indicators
- **AND** it does not call `print(...)` for loading lifecycle updates

#### Scenario: Error state is shown and closed

- **WHEN** `ImportLoadingView` presents an import error and the user taps Close
- **THEN** the error UI remains functional and `isComplete` is updated as before
- **AND** it does not call `print(...)` for error lifecycle or button actions

#### Scenario: Success state is shown and completed

- **WHEN** import completion transitions the view to success and the user taps Done
- **THEN** the success UI and completion flow behave as before
- **AND** it does not call `print(...)` for completion lifecycle or button actions
