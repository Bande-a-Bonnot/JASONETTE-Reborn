---
id: 032
status: complete
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

## Original Locked-in Test

The pre-implementation deliberate limit was pinned by
`testTrailingSlashIsNotAbsorbedByStandardization` in
`TabNavigationCoordinatorTests`. Shipping the canonical utility required flipping
that expectation so `/home` and `/home/` now collapse to the same key.

## Resolution

Completed on 2026-05-29 with a shared `URL.jasonetteCanonical` utility in
`JasonURL.swift`. The canonical form lowercases scheme/host, resolves
Foundation-standardized `.` / `..` path segments, removes trailing slashes,
drops matching default HTTP/HTTPS ports, and sorts query items.

Updated equality-style comparison sites to use the shared URL layer:

- `TabDescriptor.Target.canonicalKey` for tab dedupe and SceneStorage restore
- `TabShellState.switchToURLIfMatches` for `transition: "switch"` / action tab routing
- `JasonetteNavigationCoordinator.bootstrapDidLoad` for bootstrap entry/document URL matching
- `JasonetteTabShell` preloaded-doc hand-off matching
- `FooterTabItemView.resolvesToCurrentDocument` for legacy inline footer current-document no-op detection

The previous locked-in trailing-slash test was flipped to assert `/home` and
`/home/` now collapse to the same tab. Additional coverage proves host casing,
`https:443`, `.` / `..`, query order, and legacy current-document matching all
use the same canonical semantics.

Verification:

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter URLResolutionTests` — 24 tests, 0 failures
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter TabNavigationCoordinatorTests` — 73 tests, 0 failures
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 502 tests, 0 failures
- `cd JASONETTE-iOS/JasonetteApp && swift build`
