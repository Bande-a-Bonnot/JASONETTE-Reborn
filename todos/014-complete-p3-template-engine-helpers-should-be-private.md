---
status: pending
priority: p3
issue_id: "014"
tags: [code-review, architecture, access-control]
dependencies: []
---

# TemplateEngine Internal Helpers Are `internal` — Should Be `private`

## Problem Statement

`TemplateEngine`'s implementation helpers (`render(_:context:depth:)`, `renderArray`, `renderObject`, `interpolateString`, `findDirective`, `applyDirective`, `Directive`) are all `internal`. The public API surface is exactly one method: `render(_:context:)`. Any `@testable import` consumer can call the implementation directly, bypassing the intended entry point.

## Findings

**File:** `Sources/Jasonette/Template/TemplateEngine.swift`

All internal helpers are accessible to tests and other in-module callers even though they are implementation details. Currently the tests only call `TemplateEngine.render(...)` — which is correct — but the door is open.

All helpers are now `private`. No tests call internal methods directly — all tests use the public `TemplateEngine.render(...)` entry point.

## Proposed Solution

1. Audit test files for direct calls to internal helpers
2. Mark all implementation methods `private` except the public entry point
3. If tests need to verify internal behavior, test through the public API

## Technical Details

- **Affected files:** `Template/TemplateEngine.swift`
- **Effort:** Small

## Acceptance Criteria

- [ ] Only `render(_:context:)` is non-private on `TemplateEngine`
- [ ] No tests call implementation-detail methods directly
- [ ] Build passes with stricter access control

## Work Log

- 2026-03-12: Identified by pattern-recognition-specialist agent during code review
