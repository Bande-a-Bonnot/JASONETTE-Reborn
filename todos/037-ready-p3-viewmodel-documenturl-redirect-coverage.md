---
status: ready
priority: p3
issue_id: "037"
tags: [ios, tests, urls, redirects, viewmodel]
dependencies: []
---

# Add ViewModel redirected documentURL coverage

## Problem Statement

Codex 5.5 xhigh review on PR #24 noted that `JasonetteViewModel.load()` now uses
`DocumentLoader.loadWithMetadata(from:)` for normal URL loads, but the tests only
cover preloaded `documentURL` preservation. There is no VM-level test proving a
non-seed network load updates `JasonetteViewModel.documentURL` from the final
loaded response URL when the response URL differs from the request URL.

This is P3 coverage debt: lower-level `DocumentLoader` and coordinator tests cover
final URL metadata, but a ViewModel-level regression could accidentally switch
back to `load(from:)` or stop assigning `documentURL`.

## Recommended Action

Add a `ViewModelTests` case that:

1. Constructs `JasonetteViewModel(url:)` with an original request URL.
2. Uses a stubbed loader/session seam or testable injection point to return a
   `LoadedDocument` whose `url` is a different final URL.
3. Calls `await vm.load()` / `await vm.loadIfNeeded()`.
4. Asserts `vm.documentURL == finalURL` and the document rendered/loaded.

If direct loader injection is not currently available, introduce the smallest
internal/testable seam needed without changing public API.

## Acceptance Criteria

- [ ] A normal non-preloaded `JasonetteViewModel(url:)` load updates
      `documentURL` to the final loaded response URL.
- [ ] Test fails if `JasonetteViewModel.load()` regresses to ignoring
      `DocumentLoader.LoadedDocument.url`.
- [ ] Existing iOS test suite still passes.

## Notes

Source: local Codex 5.5 xhigh review cycle on PR #24 after footer-tab relative
URL resolution follow-ups.
