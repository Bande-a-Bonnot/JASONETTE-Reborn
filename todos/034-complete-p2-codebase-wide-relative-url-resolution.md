---
status: complete
priority: p2
issue_id: "034"
tags: [ios, urls, renderer, actions]
dependencies: []
---

# Resolve relative URLs outside shell-mounted tab descriptors

Completed: 2026-05-08

## Problem Statement

Todo/030 fixed relative URL resolution for shell-mounted footer tabs by adding
`JasonURL.resolve(_:against:)` and plumbing the bootstrap document URL into
`TabDescriptor.init(from:baseURL:)`. The rest of the renderer still contains
plain `URL(string:)` parses with no document-base context, so relative URLs in
body components/actions can still fail scheme validation or render as blank
assets. This includes the legacy `FooterTabItemView` path; todo/030 covered the
new shell-mounted `TabDescriptor` path only.

## Findings

Audit from todo/030 found these remaining call sites:

- `Rendering/JasonetteViewModel.swift` — `handleHref(_:)`
- `Rendering/JasonetteView.swift` — `FooterInputView.footerButton` and legacy
  `FooterTabItemView`
- `Components/ButtonComponent.swift` — button image URL
- `Components/ImageComponent.swift` — image URL
- `Core/ActionDispatcher.swift` — `$network.request` `options.url`

These sites need the currently loaded document URL threaded through their view
model/component/action context before they can safely use `JasonURL.resolve`.

## Recommended Action

1. Thread/expose the existing `JasonetteViewModel.documentURL` context to
   rendering/action code that parses authored URL strings.
2. Replace plain `URL(string:)` at the audited sites with
   `JasonURL.resolve(raw, against: documentURL)`.
3. Keep scheme allowlist checks after resolution.
4. Add tests for body image/button/href/network relative URLs.

## Acceptance Criteria

- [x] Body image/button URLs resolve relative to the loaded document URL
- [x] `href.url` resolves relative to the loaded document URL before push/modal/web/app/switch dispatch
- [x] `$network.request.options.url` resolves relative to the action document URL
- [x] Existing disallowed-scheme protections still reject `file:` / `javascript:` after resolution
- [x] Tests cover relative path and leading-slash path for at least href and one asset component

## Completion Notes

- Added `JasonURL.resolve(_:against:allowedSchemes:)` so scheme checks happen
  after relative URL resolution.
- Threaded `JasonetteViewModel.documentURL` into `ActionDispatcher`,
  `ComponentView`, nested `LayoutView`, body image/button components, footer
  input buttons, and the legacy footer-tab-item icon path.
- `$href` navigation and `$network.request.options.url` now resolve authored
  relative paths against the current loaded document URL before their existing
  scheme allowlist checks.
- Added tests for relative and root-relative `$href`, relative and root-relative
  `$network.request`, post-resolution scheme rejection, and representative asset
  renderers.
- Verified with `cd JASONETTE-iOS/JasonetteApp && swift test` on 2026-05-08:
  427 tests, 0 failures.

## Notes

- Do not conflate this with todo/032 URL identity normalization. This todo is
  about resolving authored relative references; todo/032 is about canonical URL
  equality semantics.
- Created as the broader follow-up from completing footer-tab-specific todo/030.
