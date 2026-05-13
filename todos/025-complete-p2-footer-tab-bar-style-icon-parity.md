---
status: complete
priority: p2
issue_id: "025"
tags: [ios, tabs, ux, code-review]
dependencies: []
---

# Restore footer-tab-bar style/icon parity with legacy footer

Completed: 2026-05-12

## Problem Statement

`FooterTabBar` (the new `safeAreaInset` tab bar introduced in PR #20)
renders tab items with a hard-coded label layout: `text` above an
`AsyncImage` for `image`, no selected/unselected state styling, no
badge, no style merging with the global footer style block.

The legacy `FooterInputView.footerButton` path honoured:

- `style.background` / `style.color` on the item
- `badge` overlay
- Selected-vs-unselected tint
- SF Symbol resolution when `image` is a `system://` URL
- `imageURL` with a failure placeholder

The shell-mounted footer currently drops all of that. Gemini flagged
this as a visible UX regression during review of PR #20.

## Findings

- Source: Gemini review on PR #20, 2026-04-19
- New file: `JASONETTE-iOS/.../Navigation/FooterTabBar.swift`
- Compare to: `JASONETTE-iOS/.../Rendering/JasonetteView.swift`
  (`footerView` + `footerButton`) for the legacy rendering path
- `TabLabelSpec` already carries `text`, `iconURL`, `badge`, `style` —
  the data is threaded through, just not consumed by the view

## Recommended Action

1. Port the `footerButton` styling logic into `FooterTabBar`:
   - Apply `style.background` / `style.color` with the same merging
     rules as legacy
   - Emit a selected-state colour (use `AccentColor` fallback when the
     style block is silent)
   - Honour `badge` as a top-trailing overlay
   - Route `system://` image URLs through the SF-symbol path
2. Add a failure placeholder for `AsyncImage` (matches todo/022 pattern
   for the non-tab footer).
3. Snapshot or view-inspector tests: selected vs unselected, with and
   without icon, with and without badge.

## Acceptance Criteria

- [x] Tab icons, text colour, background, and badge match legacy
      footer parity for the same input JSON
- [x] Selected-tab indicator is visible (colour, weight, or fill swap)
- [x] SF-symbol image URLs render as symbols, not AsyncImage fetches
- [x] Failed AsyncImage fetch shows a placeholder icon, not an
      invisible tappable area
- [x] Tests cover selected / unselected / badge / symbol / network-icon

## Completion Notes

- `FooterTabBar` now consumes `TabLabelSpec.style` for cell background,
  text/icon tint, spacing, and icon width/height while keeping width/height
  scoped to the icon like the legacy typeless footer-tab path.
- Selected tabs use the style colour or AccentColor fallback plus a visible
  capsule indicator; unselected tabs use dimmed style colour or `.secondary`.
- `system://...` tab images are converted to SF Symbol names on the descriptor
  and rendered with `Image(systemName:)`, bypassing `AsyncImage`.
- Network icon failures render a visible `photo` placeholder instead of a blank
  tappable target.
- Coverage added in `TabNavigationCoordinatorTests` for system symbols and
  footer-tabs style inheritance/inline override; existing icon and badge tests
  continue to cover descriptor threading. Full iOS suite: 431 tests passing.

## Notes

- Keep selection-change logic inside the shell — this todo is only
  about rendering parity, not navigation behaviour.
- If a shared tab-bar-item view emerges, put it under
  `Rendering/Navigation/` so the legacy footer path stays untouched.
