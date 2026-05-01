---
status: ready
priority: p3
issue_id: "038"
tags: [ios, tests, urls, tabs]
dependencies: []
---

# Add footer-tab app-scheme descriptor coverage with baseURL

## Problem Statement

Codex 5.5 xhigh review on PR #24 noted that the coordinator now always builds
footer-tab descriptors with `TabDescriptor(from:baseURL:)`. Existing tests cover
relative document/web/app href resolution and `mailto:` app-scheme acceptance,
but there is no focused descriptor test for a non-hierarchical absolute app URL
such as `mailto:` or `tel:` while a `baseURL` is also supplied.

This is P3 test coverage debt. It guards the intended behavior that absolute app
scheme URLs remain absolute and are not corrupted by Foundation
`URL(string:relativeTo:)` when a document base URL is present.

## Recommended Action

Add a `TabNavigationCoordinatorTests` / descriptor test that:

1. Creates a footer-tab `JasonComponent` with `href.view == "app"` and an absolute
   non-hierarchical URL, e.g. `mailto:test@example.com` or `tel:+15551234567`.
2. Passes a normal HTTPS `baseURL` to `TabDescriptor(from:baseURL:)`.
3. Asserts the descriptor target is `.app` with the original app-scheme URL.

## Acceptance Criteria

- [ ] `TabDescriptor(from:baseURL:)` preserves absolute non-hierarchical app URLs.
- [ ] App-scheme allowlist behavior remains unchanged (`mailto`, `tel`, `sms`,
      `http`, `https` accepted; unsafe schemes rejected).
- [ ] Existing iOS test suite still passes.

## Notes

Source: local Codex 5.5 xhigh review cycle on PR #24 after footer-tab relative
URL resolution follow-ups.
