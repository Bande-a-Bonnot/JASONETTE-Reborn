---
title: "Reviving a decade-old cross-platform project: patterns, pitfalls, and compounded learnings"
date: 2026-03-02
category: architecture-patterns
tags: [revival, cross-platform, ios, android, web, swift, kotlin, typescript, spm, tuist, jetpack-compose, swiftui, testing, code-review, monorepo]
module: JASONETTE-Reborn
symptom: "Abandoned 2016-era framework (Obj-C, Java, vanilla JS) with deprecated APIs, dead dependencies, and security vulnerabilities needs modernization across 3 platforms"
severity: architectural
resolution_time: "5 days, 55 commits, 6 phases, 9 plans, 7 PRs"
related:
  - docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md
  - docs/solutions/tuist-spm-quick-reference.md
  - docs/solutions/test-failures/tests-pass-but-feature-broken.md
  - docs/solutions/android-compose-state-hoisting.md
  - docs/solutions/integration-issues/automated-review-triage-patterns.md
  - docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md
  - docs/solutions/integration-issues/github-pages-static-json-hosting.md
  - docs/solutions/integration-issues/getmac-github-actions-runner-queue-forever.md
  - docs/solutions/build-errors/xcode-cloud-ci-post-clone-working-directory.md
  - docs/solutions/build-errors/xcode-cloud-itms90035-distribution-signing.md
---

# Reviving a Decade-Old Cross-Platform Project

Jasonette was a pioneering JSON-to-native framework (2016, 5,200 GitHub stars iOS, 1,600 Android). The maintainer disappeared in 2018. This documents what we learned reviving it across iOS, Android, and web with modern stacks.

## 1. Assess Before You Rewrite

The original codebases were unsalvageable:

| Platform | Blocker | Severity |
|----------|---------|----------|
| iOS (Obj-C) | `UIWebView` rejected by App Store since April 2020 | Fatal |
| iOS (Obj-C) | 42 CocoaPods entering read-only Dec 2026 | Fatal |
| Android (Java) | `jcenter()` shut down Aug 2024 | Fatal |
| Android (Java) | compileSdk 28, requires 35+ | Fatal |
| Web (vanilla JS) | `Function()` constructor for eval | Security hole |

**Learning:** When legacy blockers are fatal (dead repos, banned APIs), rewrite from scratch. Port the *protocol*, not the code. The `$jason` JSON markup language was the real innovation — the Obj-C/Java implementations were just one expression of it.

## 2. Specify First, Implement Second

Before writing any platform code, we created:

1. **Formal protocol spec** (`$jason` v2.0) — 15 sections defining components, actions, templates, navigation
2. **JSON Schema** (Draft 2020-12) — machine-readable validation
3. **Conformance test fixtures** — input/expected-output pairs including adversarial security cases
4. **Action catalogue** — tiered (v1.0 core, v1.1 extended, v1.2 advanced)

This paid off immediately: when the schema was validated against 79 real Jasonpedia files, `oneOf` + `additionalProperties: false` proved too strict. We caught this *before* any platform consumed the schema.

**Learning:** Validate your specification against real-world data before coding against it. `anyOf` with relaxed constraints beats `oneOf` with strict constraints for SDUI schemas.

## 3. Web First, Then Native

Build order was deliberate: web (smallest surface, fastest feedback) -> iOS -> Android.

TypeScript template engine became the *reference implementation*. Swift and Kotlin ports could test against identical conformance fixtures. Bugs found on web (like `jsep` not parsing the `in` operator by default, or `ThisExpression` being a separate AST node type) were preemptively fixed in native ports.

**Learning:** The fastest-iteration platform should be your reference implementation. Port correctness, not code.

## 4. Expression Evaluation Is a Security Minefield

We evaluated 4 JavaScript expression libraries before building a custom one:

| Library | Status | Issue |
|---------|--------|-------|
| `expression-eval` | Archived 2023 | Unmaintained |
| `expr-eval` | Active | CVE-2025-12735, CVE-2025-13204 (prototype pollution) |
| `jse-eval` | Active | Explicitly states "does NOT sandbox" |
| `Function()` constructor | Legacy Jasonette | Arbitrary code execution |

**Solution:** JSEP (JavaScript Expression Parser) + custom AST walker. JSEP only *parses* — it produces an AST without evaluating anything. Our walker evaluates with an explicit allowlist of operations and prototype pollution prevention.

**Learning:** Never use `eval()`, `Function()`, or libraries that say "not sandboxed" for user-provided expressions. Parse to AST, then walk with an allowlist.

## 5. Template Engine Regex Gotcha

`{{$jason.first}} {{$jason.last}}` was matching as a *single* expression. The regex `/^\{\{(.+?)\}\}$/` with `^...$` anchors forced the non-greedy `.+?` to stretch across `}} {{` because anchors demand matching the entire string.

**Learning:** Non-greedy quantifiers are meaningless when start/end anchors constrain the match to exactly one possibility. Match "anything except the closing delimiter" instead of relying on non-greedy.

## 6. SwiftUI Does NOT Recycle Views in LazyVStack

Widely assumed to work like UICollectionView. It does not. Memory accumulates as users scroll. Only `List` recycles (backed by UICollectionView since iOS 16) but `List` is too opinionated for server-driven UI.

**Solution:** UICollectionView + CompositionalLayout for scrolling/recycling, with SwiftUI views as cell content via `UIHostingConfiguration` (iOS 16+).

**Gotchas:**
- `NavigationLink` does not work inside `UIHostingConfiguration`
- `@State` is reset on cell reuse (must lift state to external store)
- Cannot nest lazy containers inside cells (causes layout loops)

## 7. Compose State Hoisting Is Non-Negotiable for SDUI

Compose input components using internal `remember {}` state lost values on recomposition. State was invisible to the ViewModel and to `$get` template references.

**Solution:** All input components must be stateless — accept `value` and `onValueChange` callbacks. State managed centrally via `StateManager`. See: `docs/solutions/android-compose-state-hoisting.md`

## 8. SPM Libraries Can Contain @main (Executables Cannot)

SPM executable targets are standalone binaries — they cannot be linked into Xcode app targets. But SPM *library* targets containing `@main` structs can be linked, and the linker finds the entry point.

This enabled sourceless Tuist shell targets (pure config: signing, bundle ID, assets) that link SPM libraries containing the actual `App` struct. See: `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`

**Learning:** `@main` struct must be `public` with `public init()` when in a library target.

## 9. "Tests Pass" != "It Works"

The defining lesson of this project. 198 tests passed. Vite build succeeded. Every phase marked complete. But the shipped CLI binary was completely broken (`MODULE_NOT_FOUND`).

**Root cause:** Tests ran against TypeScript source via vitest/tsx. The compiled JavaScript binary that users actually run was never tested. `bin/cli.js` did not exist on disk.

**Learning:** Always smoke-test the shipped artifact, not just the source code. See: `docs/solutions/test-failures/tests-pass-but-feature-broken.md`

## 10. Vite Library Mode Silently Drops Files

Vite library mode only bundles what the JS entry point imports. A standalone `jasonette.css` file not in the import graph was silently excluded from `dist/`. No warning.

**Learning:** Always verify `dist/` contents after build. Add explicit `cp` commands for assets outside the import graph.

## 11. Split TypeScript Configs for DOM + Node

A package with both browser code (renderer) and Node code (CLI) cannot share one tsconfig. Browser code needs `lib: ["DOM"]`; Node code needs `@types/node`. A single config produces type errors in one or both.

**Fix:** Two tsconfig files: `tsconfig.json` (browser) and `tsconfig.node.json` (CLI). See: `docs/solutions/typescript-dom-node-split-configs.md`

## 12. Automated Review Triage Patterns

Three automated reviewers (Gemini, Greptile, Copilot) produced findings across 7 PRs. Quality varied wildly.

| Category | Action |
|----------|--------|
| Security findings (XSS, path traversal, SSRF) | Almost always real. Fix immediately. |
| Type safety (ClassCastException, unsafe casts) | Usually real. Fix. |
| Architecture opinions (dependency injection, patterns) | Often intentional trade-offs. Explain in reply. |
| Package version complaints | Dismiss if CI passes and lockfile matches. |
| Timing inconsistency | Gemini: 0 to 15+ minutes. Sometimes no review at all. |

**Rule:** Every comment gets a reply — "Fixed in commit X" or "Intentional because Y." No silent ignoring. See: `docs/solutions/integration-issues/automated-review-triage-patterns.md`

## 13. npm Workspaces Are Not pnpm Workspaces

`"workspace:*"` is pnpm syntax. npm workspaces use the actual version string and resolve local packages automatically. Using pnpm syntax produces confusing install errors.

## 14. SourceKit False Positives in Multi-File Swift Packages

SourceKit reports dozens of "unresolved identifier" errors when analyzing individual files without building the full module. Cross-file references appear broken to the analyzer but compile fine.

**Learning:** Ignore SourceKit diagnostics when scaffolding a new Swift package. Run `swift build` to get real errors.

## 15. `replace_all` Can Create Dangling JSON Commas

Bulk-removing `"additionalProperties": false` lines from JSON Schema left trailing commas on preceding lines, producing invalid JSON. Always check for structural artifacts after bulk text replacements.

## 16. Kotlin intOrDouble Dispatch Bug

A helper function tried to derive the `Double` version of an `Int` operation by testing `intOp(1, 1)`. This produced wrong results for subtraction (`1-1=0`, so the function concluded the Double op must be division).

**Fix:** Pass both `Int` and `Double` operation lambdas explicitly. Never try to infer one arithmetic operation from another.

## 17. Parallel Work While Waiting for Reviews

While Gemini reviewed PR N, work began on PR N+1 on a new branch. This maximized throughput but required careful branch management. Each milestone got its own branch and PR, creating natural checkpoints.

## 18. Research Agents Before Implementation

Before each major phase, 6-10 specialized research agents were launched in parallel (architecture strategist, security sentinel, pattern recognition, etc.). Their findings were synthesized into the plan before any code was written. This front-loaded decisions and prevented rework.

## 19. Content Filtering Can Block Mundane Operations

The API blocked output 5 times in a row over ~12 hours during mundane scaffolding work (removing `.git` directories, creating project structure). No clear indication of what triggered it. Context reset eventually resolved it.

**Learning:** Save progress frequently. Commit often, early, and eagerly (as CLAUDE.md says). If you lose context, the git history *is* the context.

## Summary Statistics

| Metric | Value |
|--------|-------|
| Calendar time | 5 days (Feb 26 – Mar 2, 2026) |
| Commits | 55 on main |
| Phases completed | 6 (0 through 5, including 0.5) |
| Plans written | 9 |
| PRs merged | 7 |
| Solution docs created | 19 |
| Platforms rewritten | 3 (iOS, Android, Web) |
| Languages | Swift, Kotlin, TypeScript (replacing Obj-C, Java, vanilla JS) |
| Tests | 165 (iOS) + 58 (web) + 85 (Android) |
| Review comments triaged | ~25 across 7 PRs |
| Security findings fixed | 6 (web) + 2 (Android) |

## Cross-References

All 16 solution docs created during the revival:

**Architecture:** `android-compose-state-hoisting.md`, `architecture-patterns/tuist-spm-multiplatform-testflight.md`, `tuist-spm-quick-reference.md`

**Debugging:** `swift-caseless-enum-no-init.md`, `swift-recursive-codable-structs.md`, `kotlin-intordouble-operator-dispatch.md`, `kotlin-json-safe-cast.md`

**Build:** `build-errors/cli-binary-not-compiled.md`, `build-errors/vite-library-mode-css-not-bundled.md`, `build-errors/swift-canImport-vs-os-platform-check.md`, `build-errors/swiftui-modifier-gotchas.md`

**Config:** `npm-workspace-version-protocol.md`, `typescript-dom-node-split-configs.md`, `ci-self-hosted-runner-getmac.md`

**Testing:** `jsdom-test-quirks.md`, `test-failures/tests-pass-but-feature-broken.md`, `test-failures/ios-test-isolation-patterns.md`

**Integration:** `integration-issues/github-tree-vs-blob-urls.md`, `integration-issues/automated-review-triage-patterns.md`

## 20. Test Isolation Requires Dependency Injection Everywhere

Writing 97 new tests across iOS and Android revealed that every external dependency must be injectable for reliable testing. `UserDefaults.standard`, `URLSession.shared`, and global timer dictionaries all caused test pollution when shared.

**Pattern:** Default parameter values make injection backward-compatible:

```swift
// Production callers: StateManager() — uses .standard
// Test callers: StateManager(defaults: isolatedSuite)
public init(defaults: UserDefaults = .standard)
```

```swift
// Production: ActionDispatcher(stateManager: sm) — uses .shared
// Test: ActionDispatcher(stateManager: sm, session: stubbedSession)
public init(stateManager: StateManager, session: URLSession = .shared)
```

**Cross-platform fixture sharing:** Shared JSON test fixtures at the monorepo root (`test-fixtures/`) verified that iOS and Android template engines produce identical output for the same input. `#file`-relative paths in Swift and `ClassLoader.getResource()` in Kotlin resolved fixtures without hardcoded paths.

**Learning:** Plan for test isolation from the start. Adding DI after the fact requires touching every callsite — default parameters mitigate this but the refactor is still friction.

See: `docs/solutions/test-failures/ios-test-isolation-patterns.md`

## 21. Stewardship Is the Product Memory

A revival is not only a rewrite. It is an act of stewardship: deciding what must
survive, what can be modernized, and what should be left behind.

Jasonette's durable idea was never a specific Objective-C class, Java adapter,
or JavaScript helper. It was the promise that a JSON document could describe a
real app screen with native behavior. Preserving that promise required a human
through-line: compatibility pressure, taste, prioritization, and refusal to let
"modernization" become a different product wearing the old name.

Agentic coding can do a large share of the mechanical work: reading old fixtures,
writing tests, porting behavior, fixing regressions, and keeping momentum across
hundreds of small compatibility gaps. But the project still needs a steward to
hold the shape of the thing. The steward keeps asking:

- Does this still feel like Jasonette?
- Which legacy quirks are protocol, and which are accidents?
- Are demos failing because the renderer is wrong, the fixture is stale, or the
  old ecosystem changed underneath us?
- Are we shipping something people can actually use, not just something that
  satisfies a checklist?

**Learning:** In a resurrection project, the hard work is distributed. Agents can
supply relentless implementation energy, but the product memory comes from
stewardship: coherent vision, compatibility judgment, and the discipline to make
old examples work for the right reasons.
