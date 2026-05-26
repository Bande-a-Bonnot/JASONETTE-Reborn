---
status: complete
priority: p3
issue_id: "020"
tags: [enhancement, layers, code-review]
dependencies: []
---

# Handle same-axis layer constraints (both left+right or top+bottom)

## Problem Statement

When a layer sets both `left` and `right` (or both `top` and `bottom`), the current padding+alignment approach applies both independently without pinning the layer between edges. The component doesn't stretch to fill the space between the two insets.

## Findings

- Location: `JasonetteView.swift:125-150` (layerView + layerAlignment)
- CodeRabbit actionable comment on PR #13
- Current behavior: both paddings apply additively, component stays natural size
- Expected (CSS-like): component stretches between the two insets
- Original Jasonette demos only use single-edge positioning

## Recommended Action

Detect when both same-axis insets are set. When they are, use `.padding(EdgeInsets(...))` with `.frame(maxWidth: .infinity)` to stretch the component. Log a warning if this is unsupported for now.

## Acceptance Criteria

- [x] Layer with both `left` and `right` stretches horizontally between insets
- [x] Layer with both `top` and `bottom` stretches vertically between insets
- [x] Single-edge positioning continues to work unchanged

## Notes

Source: CodeRabbit actionable comment on PR #13 (2026-03-29)

## Completion Notes

Completed on 2026-05-26.

- Added `LayerPositioning`, a testable helper that derives layer insets,
  same-axis stretch flags, and ZStack alignment from `JasonStyle` positioning
  fields.
- Updated layer rendering to apply one `EdgeInsets` padding and stretch with
  `.frame(maxWidth: .infinity)` when `left` + `right` are set, and
  `.frame(maxHeight: .infinity)` when `top` + `bottom` are set.
- Preserved single-edge behavior by only stretching when both edges on the same
  axis are present.
- Added `LayerPositioningTests` for horizontal stretch, vertical stretch,
  single-edge no-stretch, and unpositioned no-stretch behavior.

Verification:

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter LayerPositioningTests`
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 496 tests, 0 failures
- `cd JASONETTE-iOS/JasonetteApp && swift build`
- `npm run lint:md` — 0 errors
