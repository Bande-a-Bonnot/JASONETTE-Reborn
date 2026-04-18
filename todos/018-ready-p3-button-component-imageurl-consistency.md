---
status: ready
priority: p3
issue_id: "018"
tags: [code-quality, components, code-review]
dependencies: []
---

# ButtonComponent should use imageURL for image fallback consistency

## Problem Statement

`ImageComponent` uses `component.imageURL` (which falls back from `url` to `image`), but `ButtonComponent` still uses `component.url` directly. This inconsistency means buttons won't display images provided via the `image` field (e.g., in footer input scenarios).

## Findings

- Location: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/ComponentRegistry.swift:53-54`
- `ImageComponent` was updated to use `imageURL` in PR #15
- `ButtonComponent` was not updated

## Recommended Action

Change `ButtonComponent(text: component.text, url: component.url)` to `ButtonComponent(text: component.text, url: component.imageURL)`.

## Acceptance Criteria

- [ ] ButtonComponent uses `component.imageURL` instead of `component.url`
- [ ] Tests pass

## Notes

Source: CodeRabbit nitpick on PR #15, 2026-03-30
