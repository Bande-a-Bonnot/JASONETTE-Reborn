---
id: "01a0dd6d-49aa-768a-adfa-d205c7c43cef"
status: open
priority: p2
issue_id: "104"
tags: [ios, rendering, layout, qa]
dependencies: []
---

# Constrain horizontal layouts and support equal-width distribution

## Observed problem

The Horizontal Layout demo requests `distribution: equalsize` for two paragraph
labels in each row. Instead of wrapping into equal-width columns, the text
renders as single lines extending beyond the viewport. The nested layout's
second tweet also clips at the right edge. Luna reproduced the horizontal demo
and captured unchanged screens after page-level right/down scroll attempts;
those attempts do not prove all inner scroll content is unreachable.

## Reproduction and evidence

1. Open the normal iOS app → Tutorial → View → Layout → Horizontal Layout.
2. Inspect both paragraph rows in the first viewport.
3. Return to Layout → Complex Nested Layout and inspect the second tweet text.

Expected: the equalsize row divides the available width between its children;
paragraphs wrap within those widths. Nested fill layouts constrain text to the
available row width.

Observed: only the beginning of each long line is visible.

- [Horizontal example](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-top.png)
- [Repeated scroll result](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-after-right.png)
- [Nested example](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-nested-top.png)
- [QA report](../docs/qa/2026-09-26-ios-luna-exploratory-qa.md)

## Source corroboration

`Jasonpedia/view/layout/horizontal.json` authors `distribution: equalsize`.
`Jasonette-documentation/docs/layout.md` defines equal-width children that fill
the horizontal layout and `fill` as the default distribution. `JasonStyle` in
`Core/JasonDocument.swift` has no distribution field or CodingKey.
`Components/LayoutView.swift` wraps every horizontal layout in a horizontal
ScrollView, which offers unbounded horizontal space to its children.

## Definition of Done

- Equal-size horizontal children share available width and wrap paragraph text.
- Nested horizontal/vertical content remains within its available row width.
- Authored dimensions, padding, spacing, and intended horizontal section
  scrolling retain their semantics.
- Any new style property is decoded, merged, and consumed by rendering.
- A focused regression check covers the layout contract, and screenshots of
  the horizontal and nested demos demonstrate the corrected visual result.
