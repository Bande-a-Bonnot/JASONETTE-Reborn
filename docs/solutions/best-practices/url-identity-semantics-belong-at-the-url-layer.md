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

The "obvious" response is to extend `canonicalKey` with local normalization
(lowercase the host, trim the trailing slash, sort the query). We deliberately
did not do that, and the PR shipped with the narrow semantics preserved. This
doc captures why, so the next engineer who gets the same review comment — or is
tempted to fix it themselves — knows the answer.

## Guidance

**Pick one scope for URL identity and keep it there.** In a codebase where
several subsystems compare URLs (tab match, deep-link dispatch, webview
navigation, cache keys, auth redirects), "what counts as the same URL" must be
answered in exactly one place. The right place is the URL layer — a single
extension or type — not each call site.

**Match the host's semantics until you're ready to change them everywhere.**
Swift's `URL.==` does not normalize host case, trailing slashes, default ports,
or query order. `URL.standardized` only resolves `.` / `..` path segments. If a
new call site adds its own richer normalization, it will match URLs that the
rest of the codebase treats as distinct — producing the worst kind of bug: the
tab highlights correctly but deep-link dispatch misses, or the cache key hits
but the webview navigates as if it were a fresh URL.

**Pin the deliberate limit with a test.** If you're consciously *not*
normalizing something, write the test that fails the moment someone "helpfully"
adds the normalization without doing the codebase-wide work:

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

**Leave the "do it once, globally" ticket in `todos/`.** The actual utility
belongs in a dedicated PR with its own review — it touches cache keys,
deep-link matching, auth redirects, and tab dedup simultaneously. That work is
tracked in `todos/032-nice-to-have-p3-codebase-wide-url-normalization.md`:

```swift
extension URL {
    /// Jasonette-normalized form: lowercased scheme/host, trailing slash removed,
    /// default port dropped, query parameters sorted. Use for any equality-style
    /// comparison where "looks the same to a user" should equal "is the same URL".
    var jasonetteCanonical: URL { ... }
}
```

When that lands, every `canonicalKey`, `switchToURLIfMatches`,
`bootstrapDidLoad` match, and cache-key call site migrates together.

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

Shipping the narrow semantics plus the pinned test plus the tracked todo keeps
the cost visible. The next PR review that raises the same concern has a single
answer: "yes, and here is the ticket; here is the test that will break when we
do it; here is why we're not doing it piecemeal."

## When to Apply

- Any derived-key function built from a URL (`canonicalKey`, cache key, dedup key)
- Review comments asking for "just a bit more normalization" at a specific call site
- Code reading `URL.standardized` and tempted to chain further transformations
- Multi-subsystem codebases where URL equality is checked in several layers

## Examples

### Do: keep the call site narrow, pin the limit, track the global fix

```swift
// TabDescriptor.swift — deliberate narrow scope, documented in place
var canonicalKey: String {
    switch self {
    case .document(let url): return "doc:\(url.standardized.absoluteString)"
    case .web(let url):      return "web:\(url.standardized.absoluteString)"
    case .app(let url):      return "app:\(url.standardized.absoluteString)"
    }
}
// Comment above: "Trailing slashes and host casing are NOT normalized —
// URL.standardized only resolves . / .. path segments. That matches how URL
// equality already behaves everywhere else in Jasonette."
```

Paired with `testTrailingSlashIsNotAbsorbedByStandardization` and
`todos/032-nice-to-have-p3-codebase-wide-url-normalization.md`.

### Don't: silently fix it in one place

```swift
// Tempting, but wrong in isolation
var canonicalKey: String {
    let host = url.host?.lowercased() ?? ""
    let path = url.path.hasSuffix("/") ? String(url.path.dropLast()) : url.path
    return "doc:\(url.scheme ?? "")://\(host)\(path)"
}
```

This matches `/home` and `/home/` in tab selection, but the deep-link
dispatcher, webview navigator, and cache still treat them as different URLs.
Result: users see the right tab highlight but the wrong content, and the bug
report blames "caching."

## Related

- `todos/032-nice-to-have-p3-codebase-wide-url-normalization.md` — the tracked global fix
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/Navigation/TabDescriptor.swift` — the narrow call site with the scope comment
- `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/TabNavigationCoordinatorTests.swift` — `testTrailingSlashIsNotAbsorbedByStandardization` pins the limit
- `docs/solutions/architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md` — uses `canonicalKey` for `@SceneStorage` restoration
- `docs/solutions/best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md` — adjacent pattern: how to respond to multi-reviewer pushback with scope discipline
- PR #20 (merged as `11b9fca`) — review rounds 6 and 7 flagged the limit; this doc is the institutional answer
