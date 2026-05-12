---
status: complete
priority: p2
issue_id: "030"
tags: [ios, urls, tabs, icons]
dependencies: []
---

# Resolve relative URLs in shell-mounted tab descriptors only

Completed: 2026-04-29

## Problem Statement

gemini-code-assist flagged the shell-mounted footer tab `TabDescriptor.init(from:)` for
unconditional `URL(string:)` on `item.image` and the href/url
strings. A relative path like `"icons/home.png"` or `"/home"` is
accepted by `URL(string:)`, but the resulting `URL` has no scheme
and is rejected by the scheme allowlist a few lines down. Net
effect: relative references silently disappear from the shell. This completed
fix is scoped to the shell-mounted tab path; the legacy `FooterTabItemView` path
remains tracked in `todos/034`.

This matches the pre-existing pattern elsewhere in the renderer —
icons, images, and hrefs everywhere use `URL(string:)` without a
base URL. So the correct fix is broader than footer tabs: the
renderer needs to plumb the *document's* URL through to every place
that currently parses a string as an absolute URL, and resolve
relatives with `URL(string:relativeTo:)`.

## Findings

- `TabDescriptor.init(from:)` sees the raw footer-tab `JasonComponent`
  with no document-URL context. The coordinator that calls it has
  `entryURL`, but we don't currently thread it in.
- Many other renderer sites have the same bug pattern — this is
  a cross-cutting fix, not a one-off.
- Icons on footer tabs are the most visible symptom today: an app
  hosted at `https://example.com/home.json` with `"image":
  "icons/home.png"` gets a blank icon because the resulting URL has
  no scheme.

## Recommended Action

1. Add a `baseURL: URL` parameter to `TabDescriptor.init(from:)` and
   plumb it from `JasonetteNavigationCoordinator.makeEntries` (which
   already has `entryURL`).
2. Inside, use `URL(string: str, relativeTo: baseURL)?.absoluteURL`
   before applying the scheme allowlist.
3. Audit other renderer URL parses (`ImageComponent`, `LayersView`,
   `ActionDispatcher` href, etc.) and apply the same resolution.
   Likely deserves its own helper (`JasonURL.resolve(_:against:)`)
   rather than copy-pasting the two-argument `URL` init.

## Acceptance Criteria

- [x] Shell-mounted footer tabs with relative `image` paths resolve their icon URLs
- [x] Shell-mounted footer tabs with relative `href.url` or `url` still route
      correctly (scheme check happens after resolution)
- [x] Tests cover relative → absolute resolution with and without
      a leading `/`
- [x] Audit of other renderer URL parses completed; either fixed
      or flagged with a linked todo

## Completion Notes

- Added `JasonURL.resolve(_:against:)` as the shared relative-resolution helper.
- Plumbed the loaded document URL from `DocumentLoader.loadWithMetadata` through
  `JasonetteNavigationCoordinator.bootstrapDidLoad(doc:documentURL:)` into
  `TabDescriptor.init(from:baseURL:)`.
- Shell-mounted footer-tab `image`, shorthand `url`, and `href.url` now resolve
  against the loaded document URL before scheme allowlist checks.
- Added tests for relative paths, root-relative paths, relative hrefs, relative
  icons, coordinator document-URL plumbing, response/final-URL metadata,
  original-entry-URL matching after redirects, final-URL precedence, relative vs
  absolute dedupe, missing base URLs, protocol-relative URLs, dot segments,
  query-only URLs, and disallowed schemes after resolution.
- Ran `cd JASONETTE-iOS/JasonetteApp && swift test`: 415 tests, 0 failures.
- Audit of other URL parses completed; remaining non-tab renderer/action work
  was tracked and completed in
  `todos/034-complete-p2-codebase-wide-relative-url-resolution.md`.

## Notes

Source: gemini round-4 review on PR #20
([comment 3106831645](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/pull/20#discussion_r3106831645)).
