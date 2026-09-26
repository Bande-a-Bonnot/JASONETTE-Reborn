---
id: "01a0dd6d-49aa-752c-80b9-01b4a95736e2"
status: open
priority: p2
issue_id: "105"
tags: [ios, rendering, styles, qa]
dependencies: []
---

# Paint component backgrounds across their authored bounds

## Observed problem

The Action demo authors white label tiles with width and height of 150 points.
The renderer reserves the tile space but paints white only immediately behind
the text. The result is scattered small text patches on the green page instead
of the authored white tiles.

## Reproduction and evidence

1. Open the normal iOS app → Tutorial → Action.
2. Inspect the `$util` and `$media` rows before presenting any native sheet.

Expected: each item using the `padded` class has a white 150×150 background.

Observed: the background covers the text's intrinsic bounds only. The same
shape remains visible behind the dimmed Basic Alert.

- [Undimmed Action screen](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/action-index-top.png)
- [Same layout behind an alert](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/action-alert.png)
- [QA report](../docs/qa/2026-09-26-ios-luna-exploratory-qa.md)

## Source corroboration

`Jasonpedia/action/index.json` defines the `padded` class with width/height 150
and background `#ffffff`. `Components/JasonStyleModifier.swift` applies
`.background` in `applyColors` before `applySpacing` and `applySize`, so padding
and explicit dimensions are added outside the painted view.

## Definition of Done

- Backgrounds cover the final component bounds, including authored padding and
  explicit dimensions, while foreground text styling remains correct.
- The Action demo visibly renders the authored white tiles.
- Rounded corners and borders remain aligned with the component bounds.
- A focused rendering regression check covers both padding and explicit size;
  a simulator screenshot confirms the Action demo result.
