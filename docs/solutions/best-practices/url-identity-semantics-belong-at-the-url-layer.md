---
title: "URL identity semantics belong at the URL layer, not at every call site"
date: 2026-04-19
category: best-practices
module: Navigation / URL handling
problem_type: best_practice
component: development_workflow
severity: medium
applies_when:
  - A call site needs a string key derived from a URL for equality, dedup, or routing
  - A reviewer asks you to "also lowercase the host / strip trailing slash / sort query" locally
  - `URL.standardized` is being used and you're tempted to layer extra normalization on top of it
  - Multiple subsystems (tab match, deep-link dispatch, cache keys, webview nav) compare the same URL
tags: [url, normalization, canonical-key, identity, scope, ios]
related_components: [tooling, testing_framework]
---

# URL identity semantics belong at the URL layer, not at every call site

## Context

PR #20 (tab navigation scaffold) introduced `TabDescriptor.Target.canonicalKey`,
which builds a per-tab dedup/restoration key from `url.standardized.absoluteString`.
Review rounds 6 and 7 from `gemini-code-assist` flagged — correctly — that
`URL.standardized` does *not* normalize:

- **Host casing** — `https://Example.com/` ≠ `https://example.com/`
- **Trailing slashes** — `/home` ≠ `/home/`
- **Default ports** — `https://host:443/` ≠ `https://host/`
- **Query-parameter order** — `?a=1&b=2` ≠ `?b=2&a=1`

The "obvious" response was to extend `canonicalKey` with local normalization
(lowercase the host, trim the trailing slash, sort the query). We deliberately
did not do that in PR #20, and the PR shipped with the narrow semantics
preserved. This doc captures why piecemeal normalization was deferred and how
the later global fix landed.

## 2026-05-29 Update

`todos/032` has now landed. The single codebase-wide identity utility is
`URL.jasonetteCanonical` in `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/JasonURL.swift`.
It lowercases scheme/host, keeps Foundation's standardized path-segment
resolution, removes trailing slashes, drops matching default HTTP/HTTPS ports,
and sorts query items.

Navigation equality-style comparisons now route through that utility:

- `TabDescriptor.Target.canonicalKey`
- `TabShellState.switchToURLIfMatches`
- `JasonetteNavigationCoordinator.bootstrapDidLoad`
- `JasonetteTabShell` preloaded-doc hand-off
- `FooterTabItemView.resolvesToCurrentDocument`

The old guardrail test `testTrailingSlashIsNotAbsorbedByStandardization` was
flipped to `testTrailingSlashIsAbsorbedByJasonetteCanonicalURL` as part of the
same change.

## Guidance

**Pick one scope for URL identity and keep it there.** In a codebase where
several subsystems compare URLs (tab match, deep-link dispatch, webview
navigation, cache keys, auth redirects), "what counts as the same URL" must be
answered in exactly one place. The right place is the URL layer — a single
extension or type — not each call site.

**Change URL identity semantics everywhere or nowhere.** Swift's `URL.==` does
not normalize host case, trailing slashes, default ports, or query order, and
`URL.standardized` only resolves `.` / `..` path segments. Before the global
utility existed, Jasonette intentionally matched those narrower semantics. Now
that `URL.jasonetteCanonical` exists, every equality-style comparison should use
it rather than mixing raw `URL.==`, `.standardized`, and local transformations.

**Pin deliberate limits with tests.** If you're consciously *not* normalizing
something yet, write the test that fails the moment someone "helpfully" adds the
normalization without doing the codebase-wide work. Before `todos/032` landed,
that looked like:

```swift
// JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/TabNavigationCoordinatorTests.swift
func testTrailingSlashIsNotAbsorbedByStandardization() {
    let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://a")!)
    c.bootstrapDidLoad(doc: makeDoc(tabs: [
        tabItem(url: "https://host.com/home"),
        tabItem(url: "https://host.com/home/"),
    ]))
    guard case .tabs(let shell, _, _) = c.mode else { return XCTFail("expected .tabs") }
    XCTAssertEqual(shell.tabs.count, 2,
                   "trailing slash divergence is deliberately not normalized")
}
```

The failure message tells the next engineer the test is a guardrail, not a
bug. When the codebase-wide utility ships, this test flips to
`XCTAssertEqual(shell.tabs.count, 1)` as part of that same PR.

**Do global URL identity changes as dedicated work.** The actual utility
belongs in a dedicated PR with its own review — it touches equality-style URL
matching across navigation, tab dedup, restoration, preload hand-off, and any
future URL-derived cache keys. That work landed in
`todos/032-complete-p3-codebase-wide-url-normalization.md`:

```swift
extension URL {
    /// Jasonette-normalized form: lowercased scheme/host, trailing slash removed,
    /// default port dropped, query parameters sorted. Use for any equality-style
    /// comparison where "looks the same to a user" should equal "is the same URL".
    var jasonetteCanonical: URL { ... }
}
```

When adding future equality-style URL comparisons, use `jasonetteCanonical`
instead of reintroducing ad hoc normalization at the call site.

## Why This Matters

Identity semantics are a *global* property. If tab matching says `/home` and
`/home/` are the same URL but deep-link dispatch says they're different, users
experience a correctness gap that is extremely hard to diagnose: the tab
highlights, but the content is stale; or the first navigation works, but the
second misses the cache. The only way to avoid that class of bug is to route
every equality-style comparison through one implementation.

Local "fixes" feel harmless in isolation (one file, three lines, one test) but
each one widens the inconsistency surface. They also make the eventual
consolidation harder: now you have N slightly-different normalizations to
reconcile, each with tests asserting the current-but-wrong behavior.

Shipping the narrow semantics plus the pinned test plus the tracked todo kept
the cost visible until the global utility landed. The next PR review that raises
the same concern now has a single answer: "use `URL.jasonetteCanonical`; do not
normalize locally."

## When to Apply

- Any derived-key function built from a URL (`canonicalKey`, cache key, dedup key)
- Review comments asking for "just a bit more normalization" at a specific call site
- Code reading `URL.standardized` and tempted to chain further transformations
- Multi-subsystem codebases where URL equality is checked in several layers

## Examples

### Do: use the shared canonical URL layer

```swift
// TabDescriptor.swift — one shared URL identity implementation
var canonicalKey: String {
    switch self {
    case .document(let url): return "doc:\(url.jasonetteCanonical.absoluteString)"
    case .web(let url):      return "web:\(url.jasonetteCanonical.absoluteString)"
    case .app(let url):      return "app:\(url.jasonetteCanonical.absoluteString)"
    }
}
```

Paired with canonicalization coverage in `URLResolutionTests` and
`TabNavigationCoordinatorTests`.

### Don't: silently fix it in one place

```swift
// Tempting, but wrong in isolation
var canonicalKey: String {
    let host = url.host?.lowercased() ?? ""
    let path = url.path.hasSuffix("/") ? String(url.path.dropLast()) : url.path
    return "doc:\(url.scheme ?? "")://\(host)\(path)"
}
```

This may match `/home` and `/home/` in one path, but it inevitably drifts from
other comparison surfaces. Result: users see the right tab highlight but the
wrong content, and the bug report blames "caching" or "navigation" instead of
URL identity drift.

## Related

- `todos/032-complete-p3-codebase-wide-url-normalization.md` — the completed global fix
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/JasonURL.swift` — `URL.jasonetteCanonical`
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/TabDescriptor.swift` — canonical URL tab keys
- `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/TabNavigationCoordinatorTests.swift` — `testTrailingSlashIsAbsorbedByJasonetteCanonicalURL` and related canonical matching coverage
- `docs/solutions/architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md` — uses `canonicalKey` for `@SceneStorage` restoration
- `docs/solutions/best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md` — adjacent pattern: how to respond to multi-reviewer pushback with scope discipline
- PR #20 (merged as `11b9fca`) — review rounds 6 and 7 flagged the limit; this doc is the institutional answer
