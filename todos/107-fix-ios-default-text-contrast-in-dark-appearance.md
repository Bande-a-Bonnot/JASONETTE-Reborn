---
id: "01a0dd6d-49aa-7337-81d7-9b7470e44f83"
status: open
priority: p2
issue_id: "107"
tags: [ios, rendering, accessibility, appearance, qa]
dependencies: []
---

# Keep default text and field styling legible in dark appearance

## Observed problem

Under system dark appearance, the textfield demo mixes authored light
backgrounds with incompatible system defaults. The `textfield` section heading
is nearly white on light gray, and field placeholders are very dark gray on
black field interiors. The same content is legible in light appearance.

## Reproduction and evidence

1. Open the normal iOS app → Tutorial → View → Component → textfield.
2. Switch the simulator to dark appearance and inspect the heading/placeholders.
3. Restore light appearance and compare the same screen.

Expected: default text, placeholders, and control surfaces remain readable when
the document specifies backgrounds but omits foreground colors.

Observed: heading and placeholder contrast becomes visibly poor.

- [Dark appearance](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-dark.png)
- [Restored light appearance](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-restored-light.png)
- [QA report](../docs/qa/2026-09-26-ios-luna-exploratory-qa.md)

## Investigation notes

The fixture sets `#f5f5f5` body/section backgrounds and white row backgrounds,
but no text colors for the heading or fields. `TextFieldComponent.swift` uses
system rounded-border fields and default placeholder styling. The renderer's
default presentation needs a consistent policy when authored backgrounds are
combined with system appearance. The exact contrast ratios were not measured.

## Definition of Done

- The fixture's heading and placeholders are clearly readable in both light
  and dark appearance, including focused, empty, and entered-text states.
- Preserve explicitly authored foreground and background colors.
- Apply the chosen default-color policy consistently to related text inputs.
- Capture matching light/dark regression evidence and restore simulator
  appearance after verification.
