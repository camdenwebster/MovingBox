## Context

`ImportLoadingView` currently includes ad hoc `print(...)` statements for appear/change hooks and button taps across loading, error, and success states. These logs are not structured and add noise to test and development output.

## Goals / Non-Goals

**Goals:**
- Remove ad hoc debug `print(...)` calls from `ImportLoadingView`.
- Preserve all existing UI behavior and state transitions.
- Keep change size minimal and low risk.

**Non-Goals:**
- Introduce new logging infrastructure.
- Refactor view structure, animation behavior, or state model.
- Modify import business logic outside this view.

## Decisions

### Decision 1: Remove prints rather than replacing with new logger calls

For this onboarding-sized cleanup, the lowest-risk path is deleting debug prints only. This satisfies the spec requirement (no ad hoc debug printing) while avoiding broader logging design changes.

### Decision 2: Preserve flow control and state writes verbatim

Only the side-effect logging statements are removed. Existing transitions (`showFinishButton` toggling, `isComplete` updates, cancel handling, and message animation loop) remain unchanged to prevent regressions.
