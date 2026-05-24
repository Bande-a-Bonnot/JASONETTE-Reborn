---
status: complete
priority: p3
issue_id: "036"
tags: [ios, urls, images, security, code-review]
dependencies: []
---

# Define non-tab image URL scheme policy

## Problem Statement

PR #24 tightened shell-mounted footer-tab icon URLs to the document/web URL
allowlist (`http`/`https`) after relative resolution. Other image-bearing sites
still parse authored URL strings independently and may preserve absolute
`file:` or custom-scheme image URLs.

## Recommended Action

1. Audit `ImageComponent`, `ButtonComponent`, `FooterInputView.footerButton`, and
   legacy `FooterTabItemView`.
2. Decide whether non-tab image URLs should be restricted to `http`/`https`, or
   whether local/custom schemes are intentionally supported.
3. Apply the policy consistently and add tests for `https`, `file`, and one
   custom scheme.

## Acceptance Criteria

- [x] Non-tab image URL scheme behavior is documented in code/tests
- [x] Disallowed schemes are rejected for image renderers by applying `DocumentLoader.allowedSchemes` after relative resolution
- [x] Tests cover allowed HTTP(S) relative URLs plus `file` and `custom` scheme rejection for representative image renderers
- [x] Tests pass (`cd JASONETTE-iOS/JasonetteApp && swift test`, 477 tests, 0 failures, 2026-05-24)

## Notes

Deferred from PR #24 because that PR is scoped to shell-mounted tab descriptors.
This is related to, but distinct from, `todos/034`, which tracks relative URL
base plumbing outside shell-mounted tab descriptors.
