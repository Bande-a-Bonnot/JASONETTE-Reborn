---
status: ready
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

- [ ] Layer with both `left` and `right` stretches horizontally between insets
- [ ] Layer with both `top` and `bottom` stretches vertically between insets
- [ ] Single-edge positioning continues to work unchanged

## Notes

Source: CodeRabbit actionable comment on PR #13 (2026-03-29)
