---
id: "01a0d23b-1d7d-7912-8a54-3f9de88b8a66"
status: open
priority: p3
issue_id: "103"
tags: [ios, rendering, components, qa]
dependencies: []
---

# Fix truncation in fixed-width iOS button labels

## Problem Statement

The Jasonpedia textarea fixture authors a text button labeled `Done` with a
fixed width of 60 points. On the current iOS Debug build, the rendered button
shows `Do...`, so the label is not fully legible. The 2026-05-31 capture showed
the full label; the regression is present in two 2026-09-24 captures.

`ButtonComponent` adds 14 points of horizontal padding on both sides before
`JasonStyleModifier` applies the fixed width to the outer view. This leaves
about 32 points for the text and causes truncation.

## Reproduction

1. Launch the Debug iOS app directly to
   `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/textarea/index.json`.
2. Wait for the remote fixture to finish loading.
3. Observe the red button beside the textarea.

Expected: the full `Done` label is visible within the authored 60-point width.

Actual: the label renders as `Do...`.

Evidence:

- Current screenshot, first capture:
  `docs/qa/artifacts/2026-09-24-ios-luna-qa-pass/textarea-delayed.png`
- Current screenshot, repeated launch:
  `docs/qa/artifacts/2026-09-24-ios-luna-qa-pass/textarea-current-repeat.png`
- Earlier passing screenshot:
  `docs/qa/artifacts/2026-05-31-ios-textarea-affordance/textarea-empty-affordance.png`
- Source path: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/ButtonComponent.swift`
- Fixed width is applied in `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/JasonStyleModifier.swift`.

## Definition of Done

- Text button labels remain fully visible when the authored width is sufficient
  for the text, including the existing 60-point `Done` fixture.
- The default 44-point minimum hit target remains intact.
- The textarea fixture screenshot shows the complete `Done` label.
