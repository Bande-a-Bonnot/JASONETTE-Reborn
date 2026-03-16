---
status: pending
priority: p1
issue_id: "003"
tags: [code-review, architecture, error-handling, debugging]
dependencies: []
---

# Silent Render Failure Indistinguishable From Success

## Problem Statement

Both fallback paths in `JasonetteViewModel.render()` silently fall back to `doc.jason` with no log, no error state change, and `loadState` remaining `.loaded`. A blank rendered view is indistinguishable from a document that intentionally has no body content. This makes template bugs invisible in production.

## Findings

**File:** `Rendering/JasonetteViewModel.swift`

```swift
guard JSONSerialization.isValidJSONObject(rendered) else {
    renderedRoot = doc.jason  // silent
    return
}
do {
    ...
} catch {
    renderedRoot = doc.jason  // silent
}
```

Compare with `load()` which correctly sets `loadState = .error(error.localizedDescription)` in its catch block. The render path violates this established pattern. An empty `JasonRoot{}` decoded from `{}` passes all guards, `loadState` is `.loaded`, and the view shows nothing — completely indistinguishable from success.

## Proposed Solutions

### Option A: Add `#if DEBUG` logging at both fallback sites (quick fix)

```swift
guard JSONSerialization.isValidJSONObject(rendered) else {
    #if DEBUG
    print("[Jasonette] render fallback: template produced non-serializable output")
    #endif
    renderedRoot = doc.jason; return
}
```
- Pros: Zero runtime cost in release, surfaces bugs immediately during development
- Cons: Only visible in debug console; not observable in production

### Option B: Add `.renderError` case to `LoadState` and surface it (recommended)

Add a distinct state case and set it when the template fails. Views can show a banner or fallback UI.
- Pros: Observable in production, testable, follows existing error-surfacing pattern
- Cons: API change to `LoadState`

### Option C: Use `os_log` / `Logger` framework (best for production)

Log using `os_log` at `fault` level — visible in Console.app and crash reporters (Crashlytics breadcrumbs).
- Pros: Survives into production, structured, filterable
- Cons: Slightly more boilerplate

## Recommended Action

Option A immediately (one PR), Option C as follow-up.

## Technical Details

- **Affected files:** `Rendering/JasonetteViewModel.swift` (render method, ~lines 89-109)
- **Effort:** Small

## Acceptance Criteria

- [ ] Template render failure produces a visible log entry in debug builds
- [ ] Test: `testRenderFallsBackToRawDocumentWhenTemplateInvalid` asserts on some observable signal (not just "doesn't crash")
- [ ] No silent `loadState = .loaded` when template is discarded

## Work Log

- 2026-03-12: Identified by architecture-strategist and data-integrity-guardian agents during code review
