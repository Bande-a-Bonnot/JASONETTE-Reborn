---
id: "01a0dd6d-49aa-74ef-976c-35e45923e2c5"
status: open
priority: p2
issue_id: "106"
tags: [ios, html, navigation, qa]
dependencies: []
---

# Make the Web Container SVG row navigate to its authored destination

## Observed problem

The Web Container index contains animated HTML menu rows with component-level
`href` destinations. Repeated taps on the visible `svg` row leave the app on
the HTML demo index. An attempted parent-button activation also did not reach
the destination. The SVG Clock was therefore not exercised through the app.

## Reproduction and evidence

1. Open the normal iOS app → Tutorial → Web Container.
2. Tap the visible `svg` row; avoid waiting for perpetual animation to settle.
3. Observe that the title/menu remain on HTML demo; repeat the tap.

Expected: push the authored SVG Clock document and allow app back navigation.

Observed: no visible navigation from the menu.

- [Index](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-index.png)
- [After repeated SVG tap](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-svg-after-tap.png)
- [After parent-button attempt](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-svg-parent-button.png)
- [QA report](../docs/qa/2026-09-26-ios-luna-exploratory-qa.md)

## Investigation notes

The observed failure is confirmed for this row; its cause remains to be
established. `ComponentRegistry.swift` wraps HTML-with-href in a SwiftUI Button.
`HTMLComponent.swift` hosts an interactive WKWebView without a tap bridge for
the outer component href. The menu's HTML contains text rather than a DOM link,
so WebKit consuming the tap is a plausible explanation.

Host curl checks returned HTTP 200 for the public `webcontainer/svg.json` and
`webcontainer/template2.json` URLs; both parsed responses matched local
fixtures. That establishes host availability, not simulator networking. The
agent-device network inspection failed with an xcrun timeout, so it did not
establish whether the app issued a request.

## Definition of Done

- Tapping the SVG HTML row from the normal menu opens SVG Clock in-app, with
  working back navigation; verify a second HTML menu row as well.
- Diagnose whether the failure is tap routing, href resolution, or loading.
- Preserve internal HTML interaction for components without an outer href.
- Add a focused regression check at the confirmed failure boundary and capture
  the successful in-app transition. A direct-entry launch alone is insufficient.
