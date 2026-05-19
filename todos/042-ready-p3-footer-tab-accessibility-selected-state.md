---
status: ready
priority: p3
issue_id: "042"
tags: [ios, tabs, accessibility, ux, qa]
dependencies: []
---

# Improve icon-only footer tab accessibility and selected-state visibility

## Problem Statement

The `core/href/tabs.json` fixture renders three image-only footer tabs. During
simulator QA, accessibility exposed them as unlabeled buttons and the selected
state was not clearly visible in screenshots.

## Evidence

- QA doc: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- Screenshots:
  - `docs/qa/artifacts/2026-05-18-ios-simulator/005-href-tabs.png`
  - `docs/qa/artifacts/2026-05-18-ios-simulator/006-after-tab2.png`
- Accessibility snapshot showed footer tab refs as buttons with no label.

## Recommended Action

1. Add accessibility labels for footer tab cells:
   - prefer authored `text`
   - then perhaps a future explicit accessibility field
   - then a safe fallback derived from target URL/icon name
2. Expose selected state via accessibility traits/value where possible.
3. Verify the visual selected indicator is visible for icon-only tabs and not
   clipped by safe-area/tab cell layout.
4. Add regression tests or simulator QA coverage for icon-only tabs.

## Acceptance Criteria

- [ ] Icon-only footer tabs have non-empty accessibility labels
- [ ] Selected footer tab is programmatically identifiable to accessibility
- [ ] Selected state is visually obvious in the icon-only fixture
- [ ] Existing text+icon tab rendering still works

## Notes

This is a follow-up to completed `todos/025`; the style/icon parity work landed,
but QA found accessibility and selected-state clarity still need improvement.
