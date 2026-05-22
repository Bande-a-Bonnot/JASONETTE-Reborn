---
status: ready
priority: p2
issue_id: "041"
tags: [ios, components, html, wkwebview, qa]
dependencies: []
---

# Implement HTML component rendering

## Current Status

Code fix is in progress on `main` candidate as of 2026-05-22:

- Added `HTMLComponent` backed by `WKWebView`.
- Supports inline `text` HTML with optional sibling `css` injection.
- Supports URL-backed `url` HTML, resolved relative to `documentURL` and restricted to `http`/`https`.
- `JasonComponent` decodes `css`.
- `ComponentView` dispatches `type: "html"` instead of rendering `[Unknown: html]`.
- Added ComponentDispatchTests for decoding, registry knowledge, document wrapping/CSS injection, relative URL resolution, and rejected disallowed URL schemes.
- Added a ViewModel fixture test for `Jasonpedia/view/component/html/index.json`.
- `cd JASONETTE-iOS/JasonetteApp && swift test` passes: 462 tests, 0 failures.

Still open: simulator visual QA for `Jasonpedia/view/component/html/index.json`.

## Problem Statement

The Jasonpedia HTML component demo renders literal placeholder text
`[Unknown: html]` instead of rendering HTML content.

## Evidence

- QA doc: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- Screenshot: `docs/qa/artifacts/2026-05-18-ios-simulator/008-html-component.png`
- Jasonpedia path tested: `View` → `Component` → `html`

## Recommended Action

1. Confirm the Jasonette v2 expected contract for the `html` component.
2. Add an iOS renderer for `type: "html"` (likely `WKWebView` wrapped in
   SwiftUI) with safe sizing behavior.
3. Decide how authored inline HTML vs URL-backed HTML should be handled.
4. Add unit or integration coverage for the component registry and basic
   rendering path.
5. Re-run simulator QA on the HTML component demo.

## Acceptance Criteria

- [x] `type: "html"` is recognized by `ComponentRegistry`
- [x] Jasonpedia HTML demo no longer renders `[Unknown: html]`
- [ ] HTML content is visible in the simulator
- [x] Tests cover at least the component dispatch/registration path

## Notes

This was already listed as a Phase C gap in the handoff; QA added concrete
simulator evidence.
