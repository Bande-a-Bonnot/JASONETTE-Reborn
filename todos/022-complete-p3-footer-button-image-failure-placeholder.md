---
status: complete
priority: p3
issue_id: "022"
tags: [ux, components, code-review]
dependencies: []
---

# Add failure placeholder for footer button AsyncImage

## Problem Statement

In `FooterInputView.footerButton`, the `AsyncImage` uses `Color.clear` for both `.empty` and `.failure` phases. Users see an invisible but tappable 24x24 area when an image fails to load — no visual feedback that something went wrong.

## Findings

- Location: `JasonetteView.swift:243-256` (footerButton AsyncImage)
- Copilot + CodeRabbit flagged on PR #15
- Current behavior matches `ImageComponent` pattern (also uses Color.clear)
- 24x24 is small for a spinner, but a system icon placeholder would work

## Recommended Action

Handle `.failure` separately with a system icon placeholder:
```swift
case .failure:
    Image(systemName: "photo")
        .foregroundColor(.secondary)
```

## Acceptance Criteria

- [x] Failed footer button images show a visible placeholder icon
- [x] Loading state can remain Color.clear (too small for spinner)
- [x] Tests pass (`cd JASONETTE-iOS/JasonetteApp && swift test`, 478 tests, 0 failures, 2026-05-24)

## Notes

Source: Copilot + CodeRabbit nitpick on PR #15 (2026-03-29/30)
