---
id: 032
status: nice-to-have
priority: p3
title: Codebase-wide URL normalization utility (host case, trailing slashes, default ports)
---

## Context

Gemini flagged (round 6 + round 7 of PR #20) that `TabDescriptor.Target.canonicalKey`
uses `url.standardized.absoluteString`, and that `URL.standardized` does NOT normalize:

- **Host casing** — `https://Example.com/` vs `https://example.com/` are distinct
- **Trailing slashes** — `/home` vs `/home/` are distinct
- **Default ports** — `https://host:443/` vs `https://host/` are distinct
- **Query-parameter order** — `?a=1&b=2` vs `?b=2&a=1` are distinct

The tab code deliberately does *not* normalize these locally, because `URL.==` doesn't
either — a tab-local normalization would paper over an inconsistency by introducing a
different one (tab matches via `canonicalKey` but then misses in deep-link dispatch,
webview navigation, cache keys, etc.).

## The ask

If/when we decide the Jasonette URL layer should normalize these, do it *once*, as a
codebase-wide utility:

```swift
extension URL {
    /// Jasonette-normalized form: lowercased scheme/host, trailing slash removed,
    /// default port dropped, query parameters sorted. Use for any equality-style
    /// comparison where "looks the same to a user" should equal "is the same URL".
    var jasonetteCanonical: URL { ... }
}
```

Then update all comparison sites to use it — `TabDescriptor.canonicalKey`,
`TabShellState.switchToURLIfMatches`, `JasonetteNavigationCoordinator.bootstrapDidLoad`,
deep-link dispatch, cache keys, etc.

## Locked-in tests

The current deliberate limit is pinned by these tests in
`TabNavigationCoordinatorTests`:

- `testTrailingSlashIsNotAbsorbedByStandardization`

When we ship the canonical utility, this test will need to be updated (the new
expectation is that `/home` and `/home/` collapse to the same key). The test failure
is the signal — don't change the production code without updating these.

## Why not now

1. Scope: PR #20 is tab navigation shell, not URL identity semantics.
2. Risk: normalizing URL identity changes cache keys, deep-link matching, and
   auth-redirect flows — each needs its own review.
3. Call sites: we don't yet have a catalog of every URL comparison in the codebase.
