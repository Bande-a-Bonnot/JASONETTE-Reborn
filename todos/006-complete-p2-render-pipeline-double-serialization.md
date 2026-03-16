---
status: pending
priority: p2
issue_id: "006"
tags: [code-review, performance, architecture]
dependencies: []
---

# Render Pipeline Has Unnecessary Double Serialization + Fresh Decoder Per Render

## Problem Statement

`JasonetteViewModel.render()` performs a full serialize-then-decode round-trip on every render call: `TemplateEngine` output → `JSONSerialization.data()` → `JSONDecoder().decode()`. The document was already decoded. This wastes memory and CPU on every render, and a fresh `JSONDecoder()` is constructed each time.

## Findings

**File:** `Rendering/JasonetteViewModel.swift`

Pipeline per render:
1. `head.data.compactMapValues { $0.unwrapped }` — O(n) tree walk
2. `TemplateEngine.render(templates.unwrapped, context:)` — O(n) tree walk
3. `JSONSerialization.isValidJSONObject(rendered)` — O(n) validation
4. `JSONSerialization.data(withJSONObject: rendered)` — O(n) serialize to Data
5. `JSONDecoder().decode(JasonRoot.self, from: renderedData)` — O(n) decode to typed struct

Passes 3-5 exist only because `TemplateEngine` returns `Any` instead of the typed model. `JSONDecoder()` is constructed fresh — the decoder is stateless and can be shared.

## Proposed Solutions

### Option A: Lift decoder to instance variable (quick win, no API change)

```swift
private let decoder = JSONDecoder()
```
Eliminates one allocation per render. Zero risk.

### Option B: Cache rendered result, re-render only on state change

```swift
stateManager.$local
    .removeDuplicates()
    .dropFirst()
    .sink { [weak self] _ in guard let self else { return }
        guard let doc = self.document else { return }
        self.render(doc)
    }
    .store(in: &cancellables)
```
Eliminates spurious re-renders triggered by `$render` action noise.

### Option C: Have TemplateEngine operate on AnyCodable (long-term)

Since `AnyCodable` conforms to `Codable`, `JSONDecoder` can decode directly from a tree of `AnyCodable` nodes — eliminating the `JSONSerialization` round-trip entirely.
- Effort: Large, separate PR

## Recommended Action

Option A immediately (1 line), Option B as follow-up in this PR, Option C as future work.

## Technical Details

- **Affected files:** `Rendering/JasonetteViewModel.swift`
- **Effort:** Small (Option A), Medium (Option B)

## Acceptance Criteria

- [ ] `JSONDecoder` is a `private let` on `JasonetteViewModel`, not constructed per-render
- [ ] Re-render is not triggered when `stateManager.local` hasn't changed
- [ ] All existing ViewModel tests still pass

## Work Log

- 2026-03-12: Identified by performance-oracle and architecture-strategist agents during code review
