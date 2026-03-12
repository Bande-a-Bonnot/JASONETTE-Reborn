---
status: pending
priority: p3
issue_id: "012"
tags: [code-review, conventions, uuids]
dependencies: []
---

# `AlertConfig.id` Uses `UUID()` (v4) — Violates Project UUIDv7 Convention

## Problem Statement

`JasonetteViewModel.AlertConfig` uses `let id = UUID()` which generates a UUID v4. The project `CLAUDE.md` states: "Use UUIDv7 for all IDs. Strictly." This is a minor but recurring convention violation.

## Findings

**File:** `Rendering/JasonetteViewModel.swift`

```swift
struct AlertConfig: Identifiable {
    let id = UUID()  // should be UUIDv7
    ...
}
```

## Proposed Solution

Replace with the project's UUIDv7 generator (however it's implemented — check existing usages for the pattern).

## Technical Details
- **Affected files:** `Rendering/JasonetteViewModel.swift`
- **Effort:** Trivial

## Acceptance Criteria
- [ ] `AlertConfig.id` uses UUIDv7
- [ ] Consistent with all other ID fields in the codebase

## Work Log
- 2026-03-12: Identified by pattern-recognition-specialist agent during code review
