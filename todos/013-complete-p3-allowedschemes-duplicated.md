---
status: pending
priority: p3
issue_id: "013"
tags: [code-review, architecture, dry]
dependencies: []
---

# `allowedSchemes` Defined Independently in `ActionDispatcher` and `DocumentLoader`

## Problem Statement

Both `ActionDispatcher` and `DocumentLoader` independently define `private static let allowedSchemes: Set<String> = ["https", "http"]`. If the allowed schemes ever change (e.g. add `file://` for local testing, restrict to HTTPS-only), both must be updated in sync.

## Findings

- `ActionDispatcher.swift`: `private static let allowedSchemes: Set<String> = ["https", "http"]`
- `DocumentLoader.swift`: `private static let allowedSchemes: Set<String> = ["http", "https"]`

Note: they are also in different order (ActionDispatcher: `https` first; DocumentLoader: `http` first) — cosmetic but adds to the inconsistency.

## Proposed Solutions

### Option A: Extract to a shared internal constant

In a new `URLSchemePolicy.swift` or in `DocumentLoader`:
```swift
extension DocumentLoader {
    static let allowedSchemes: Set<String> = ["http", "https"]
}
```
`ActionDispatcher` references `DocumentLoader.allowedSchemes`.

### Option B: Have ActionDispatcher call DocumentLoader's scheme check

Since `DocumentLoader.load(from:)` already validates schemes and throws `blockedURL`, `ActionDispatcher.networkRequest` could delegate validation to `DocumentLoader` or share the constant.

## Recommended Action

Option A — simple, one-file change.

## Technical Details

- **Affected files:** `Core/ActionDispatcher.swift`, `Core/DocumentLoader.swift`
- **Effort:** Trivial

## Acceptance Criteria

- [ ] Single source of truth for allowed URL schemes
- [ ] Adding a new scheme requires changing one line

## Work Log

- 2026-03-12: Identified by code-simplicity-reviewer agent during code review
