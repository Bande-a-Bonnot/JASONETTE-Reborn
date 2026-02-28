---
title: "Jasonette Revival — Milestone Execution Plan"
type: feat
date: 2026-02-27
parent_plan: docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md
parent_brainstorm: docs/brainstorms/2026-02-26-swiftui-compose-ui-framework-brainstorm.md
---

# Jasonette Revival — Milestone Execution Plan

## Overview

This plan operationalizes the [Jasonette Revival Roadmap](./2026-02-26-feat-jasonette-revival-roadmap-plan.md) into executable milestones. Each milestone gets its own dedicated plan, branch, implementation, PR, review cycle, and merge. The GitHub org is `Bande-a-Bonnot`; all repos are already forked there.

## Architectural Decisions (Resolving Spec Gaps)

Before execution, these critical questions from the SpecFlow analysis must be settled:

### D1: Multi-statement function bodies in templates

**Decision: Drop multi-statement support in v2.0.** JSEP parses expressions, not statements. The Jasonpedia `jsfunction.json` example uses `var`, `function()`, `return` — these are statements that JSEP cannot parse. Supporting them would require a full JS engine fallback, undermining the security case for JSEP + AST walker.

- Mark `jsfunction.json` as a v1.2+ feature (Tier 3, requires `$script.*` integration)
- Document as a breaking change from v1.x: "Template expressions support JavaScript *expressions* only, not statements. Use `$script.*` for multi-statement logic."
- All other template features (`{{#each}}`, `{{#if}}`, member access, ternary, function calls from allowlist) remain supported via JSEP

### D2: `$session.*` tier

**Decision: Tier 1.** The research insight is correct — `$network.request` is useless for real apps without session management. Move `$session.*` to Tier 1 in all milestones.

### D3: Template features in scope for v1.0

| Feature | In Scope (v1.0) | Deferred |
|---|---|---|
| `{{variable}}` | Yes | |
| `{{expression}}` (JS expressions via JSEP) | Yes | |
| `{{#each array}}` | Yes | |
| `{{#if}}/{{#elseif}}/{{#else}}` | Yes | |
| `$root` (parent context in nested loops) | Yes | |
| `$index` (loop index) | Yes | |
| `@` mixin (remote JSON inclusion) | Yes | |
| `$document` (local mixin references) | Yes | |
| `#let` (local variable binding) | Deferred to v1.1 | |
| `#concat` / `#merge` | Deferred to v1.1 | |
| `#?` (existential operator) | Deferred to v1.1 | |
| Multi-statement `{{ }}` (var, return, function) | Deferred to v1.2 | Requires `$script.*` |
| HTML template engine (`data_type: "html"`) | Deferred to v1.1 | |

### D4: JSEP package identity

**Confirmed: `jsep` from npm** — `github.com/EricSmekens/jsep` (not "EricSmekworthy" as the roadmap states). The roadmap reference is a typo.

### D5: Style value types

**Decision: Accept both strings and numbers.** Coerce to platform-expected type. Existing examples use strings; new examples may use numbers. Both are valid JSON.

### D6: PR review exit condition

**Policy: Maximum 3 review cycles.** After 3 push-review rounds, the maintainer makes a judgment call — merge, abandon, or split the PR. Automated reviewer false positives are dismissed with a reply explaining why.

### D7: Jasonpedia test fixtures

**Decision: Use local fixtures.** Copy all Jasonpedia JSON files and referenced assets into the test suite. Mock HTTP for mixin resolution. Do not depend on live URLs (`jasonette.github.io`, `jasonbase.com`, `pbs.twimg.com`) for conformance tests.

### D8: Webcontainers in v1.0

**Decision: Deferred.** `$agent.*` is Tier 2. Webcontainer examples are impressive but depend on the agent bridge system. Phase 1 web renderer focuses on native components and Tier 1 actions only.

### D9: Interactive playground

**Decision: Cut from v1.0.** Phase 4.3 playground deferred to v1.1.

---

## Milestone Breakdown

Each milestone follows this workflow:

```
1. Create dedicated plan → docs/plans/YYYY-MM-DD-feat-<milestone>-plan.md
2. Create branch → milestone/<name>
3. Implement with TDD (tests first, then code)
4. Commit atomically (per CLAUDE.md)
5. Open PR → Bande-a-Bonnot/<repo>
6. Request review: @codex
7. Wait for automated reviews (Gemini, Greptile, Copilot — up to 15 min)
8. Triage all comments → address relevant, reply to all
9. Re-push → wait for re-reviews (max 3 cycles per D6)
10. Merge PR when clean
11. Mark milestone complete in this plan + roadmap
12. Run /workflows:compound to document learnings
```

### Milestone 1: Phase 0 — Foundation

**Branch:** `milestone/phase-0-foundation`
**Repo:** `Bande-a-Bonnot/JASONETTE-Reborn` (parent repo)
**Scope:**

- [ ] 0.1 — Project charter, governance model (CONTRIBUTING.md, CODE_OF_CONDUCT.md)
- [ ] 0.2 — Formalize `$jason` JSON Schema v2.0:
  - Extract schema from Jasonpedia examples + original iOS/Android/Web source code
  - Write JSON Schema (json-schema.org) for editor autocompletion
  - Document every element, component, action, lifecycle hook
  - Create tiered action catalogue (Tier 1/2/3) with `$session.*` as Tier 1
  - Document template expression scope (v1.0 features per D3)
  - Document breaking changes from v1.x (per D1)
  - Document action execution model (serial chaining, lambda/trigger, return)
- [ ] 0.3 — CI/CD: GitHub Actions for web (Node.js) only at this stage
  - iOS and Android CI deferred until those projects exist (per SpecFlow recommendation)
- [ ] Create conformance test fixture set from Jasonpedia (local copies, no live URLs per D7)

**Deliverable:** Published `$jason` Schema v2.0 spec + JSON Schema file + conformance test fixtures
**Status:** [ ] Not started

---

### Milestone 2: Phase 0.5 — Template Engine

**Branch:** `milestone/phase-0.5-template-engine`
**Repo:** `Bande-a-Bonnot/JASONETTE-Reborn` (new `packages/template-engine/` directory)
**Scope:**

- [ ] Initialize TypeScript project with Vite (library mode) + Vitest
- [ ] Implement template parser: `{{var}}`, `{{#each}}`, `{{#if}}/{{#elseif}}/{{#else}}`
- [ ] Implement expression evaluator: JSEP + custom AST walker
  - Identifier resolution from `$jason` context only
  - MemberExpression for property access
  - BinaryExpression, UnaryExpression, ConditionalExpression (ternary)
  - CallExpression with function allowlist (Math.*, JSON.*, parseInt, parseFloat, etc.)
  - `$root` for parent context access in nested loops
  - `$index` for loop iteration index
- [ ] Security layers:
  - AST validation: reject AssignmentExpression (no side effects)
  - Property blocklist: `__proto__`, `constructor`, `prototype`
  - Complexity limits: max AST depth 20, max 50 nodes, 10ms timeout
  - Function allowlist only
- [ ] Implement `@` mixin operator (remote JSON inclusion)
  - Max recursion depth: 5
  - Mixin size limit: 1MB
  - SSRF blocklist for private IP ranges
  - Cache fetched mixins in memory
- [ ] Implement `$document` local mixin references
- [ ] Expression compilation cache (LRU, 1000 entries)
- [ ] Validate against all Jasonpedia template examples (local fixtures)
- [ ] Publish as `@jasonette/template-engine` (npm package)

**Deliverable:** `@jasonette/template-engine` npm package passing all conformance tests
**Status:** [ ] Not started

---

### Milestone 3: Phase 1 — Web Platform

**Branch:** `milestone/phase-1-web`
**Repo:** `Bande-a-Bonnot/Jasonette-Web` (rewrite in-place)
**Scope:**

- [ ] 1.1 — Modern web rewrite:
  - TypeScript with ES modules
  - Vite for bundling (replace Gulp v3)
  - Integrate `@jasonette/template-engine`
  - Replace cell.js with vanilla `document.createElement`
  - Vendor all dependencies (no external CDN without SRI)
  - Vitest unit tests
- [ ] 1.2 — Feature parity:
  - All components: label, button, image, textfield, textarea, html (iframe), slider, switch, space
  - Layouts: vertical, horizontal, nested
  - Header, footer (tabs + input), layers
  - Tier 1 actions: `$render`, `$reload`, `$network.request`, `$set`/`$get`, `$cache.*`, `$session.*`, `$util.*`, `$timer.*`, `$log.*`
  - Action chaining (success/error) + `$lambda`/`trigger`/`$return`
  - `$href` SPA navigation (History API, modals, tabs)
  - All lifecycle hooks: `$load`, `$show`, `$foreground` (page visibility), `$pull`
  - Style class system from `head.styles`
- [ ] 1.3 — CLI + developer experience:
  - `jasonette validate app.json --format json`
  - `jasonette serve app.json --port 3000` (live reload dev server)
  - `jasonette render app.json --output json` (structured render output)
  - JSON validation with helpful error messages

**Deliverable:** `@jasonette/web` npm package + CLI tool
**Status:** [ ] Not started

---

### Milestone 4: Gate Review

**Branch:** N/A (review only)
**Scope:**

- [ ] Verify `$jason` schema spec is stable (no changes from web implementation)
- [ ] Template engine passes 100% of in-scope Jasonpedia template tests
- [ ] All Jasonpedia view examples render correctly on web
- [ ] Action execution model (chaining, lambda, return, lifecycle) formally documented
- [ ] Action tier list finalized
- [ ] Decision: proceed with iOS, defer Android to v1.1, or adjust scope

**Deliverable:** Go/no-go decision for native platform development
**Status:** [ ] Not started

---

### Milestone 5: Phase 2 — iOS Platform

**Branch:** `milestone/phase-2-ios`
**Repo:** `Bande-a-Bonnot/JASONETTE-iOS` (rewrite in-place)
**Scope:**

- [ ] 2.1 — New Xcode project (Swift, iOS 16+, SPM only)
  - UICollectionView + CompositionalLayout + DiffableDataSource
  - UIHostingConfiguration for SwiftUI cell content
  - UINavigationController for navigation
  - `PrivacyInfo.xcprivacy` (iOS Privacy Manifest)
  - `jasonette.config.json` for app configuration
- [ ] 2.2 — Core framework:
  - Template engine port (JSEP + AST walker patterns in Swift)
  - JavaScriptCore `JSContext` for `$script.*` only (singleton per app)
  - Component registry (protocol-oriented Swift)
  - Action dispatcher (structured concurrency)
  - State management (`$get`/`$set`, `$cache.*`, `$session.*`)
  - Style class system
- [ ] 2.3 — All components (SwiftUI):
  - LabelComponent (Text), ImageComponent (AsyncImage), ButtonComponent, TextFieldComponent, TextAreaComponent, HtmlComponent (WKWebView), MapComponent, SliderComponent, SwitchComponent, SpaceComponent
- [ ] 2.4 — Tier 1 actions:
  - `$network.request`, `$render`/`$reload`, `$href`, `$lambda`/`trigger`/`$return`
  - `$util.*`, `$set`/`$get`, `$cache.*`, `$session.*`, `$timer.*`, `$log.*`
- [ ] 2.5 — Testing:
  - XCTest unit tests for parser, template engine, component factory
  - Run every Jasonpedia example and verify rendering
  - CI via GitHub Actions (xcodebuild)

**Deliverable:** Swift-based iOS app rendering `$jason` JSON natively
**Status:** [ ] Not started

---

### Milestone 6: Phase 3 — Android Platform

**Branch:** `milestone/phase-3-android`
**Repo:** `Bande-a-Bonnot/JASONETTE-Android` (rewrite in-place)
**Scope:**

- [ ] 3.1 — New Android Studio project (Kotlin, minSdk 26, targetSdk 35, AGP 9.x)
  - Jetpack Compose with LazyColumn/LazyRow
  - Compose Navigation for `$href`
  - `jasonette.config.json` for app configuration
- [ ] 3.2 — Core framework:
  - Template engine port (JSEP + AST walker patterns in Kotlin)
  - QuickJS for `$script.*` only
  - Component registry (composable dispatch)
  - Action dispatcher (Kotlin coroutines)
  - State management
  - Style class system
- [ ] 3.3 — All components (Compose):
  - LabelComponent (Text), ImageComponent (Coil AsyncImage), ButtonComponent, TextFieldComponent, TextAreaComponent, HtmlComponent (WebView), MapComponent, SliderComponent, SwitchComponent, SpaceComponent
- [ ] 3.4 — Tier 1 actions:
  - Same as iOS Tier 1
- [ ] 3.5 — Testing:
  - JUnit + Compose testing for unit and UI tests
  - Run every Jasonpedia example
  - CI via GitHub Actions (Gradle)

**Deliverable:** Kotlin-based Android app rendering `$jason` JSON natively
**Status:** [ ] Not started

---

### Milestone 7: Phase 4 — Jasonpedia Refresh

**Branch:** `milestone/phase-4-jasonpedia`
**Repo:** `Bande-a-Bonnot/Jasonpedia`
**Scope:**

- [ ] 4.1 — Audit and fix all 100 JSON examples:
  - Fix broken URLs (re-host under `Bande-a-Bonnot` GitHub Pages)
  - Remove references to dead services (`jasonbase.com`, dead Twitter image URLs)
  - Update to v2.0 schema (remove multi-statement template expressions)
  - Cross-platform font name mapping (generic families)
- [ ] 4.2 — Expand coverage:
  - Dark mode, dynamic type, accessibility examples
  - Edge cases: empty data, error states, large lists
  - Integration test examples (multi-screen flows)

**Deliverable:** Updated Jasonpedia with all examples verified across platforms
**Status:** [ ] Not started

---

### Milestone 8: Phase 5 — Ecosystem & Community

**Branch:** `milestone/phase-5-ecosystem`
**Repo:** `Bande-a-Bonnot/JASONETTE-Reborn` + `Bande-a-Bonnot/Jasonette-documentation`
**Scope:**

- [ ] 5.1 — Documentation site (MkDocs or VitePress)
  - Getting started guide, API reference, tutorials
  - Migration guide from original Jasonette
  - Comparison with DivKit, Hyperview
- [ ] 5.2 — Developer tools:
  - JSON Schema published to SchemaStore
  - CLI improvements based on Phase 1 feedback
- [ ] 5.3 — Governance:
  - CONTRIBUTING.md with clear guidelines
  - RFC process for schema changes
  - Release cadence documentation
- [ ] 5.4 — Community launch:
  - "Jasonette is Back" blog post
  - HN, Reddit, Discord announcements
  - GitHub Sponsors setup

**Deliverable:** Documentation site, governance structure, community launch
**Status:** [ ] Not started

---

## Dependency Graph

```
Milestone 1 (Phase 0: Foundation)
    |
    v
Milestone 2 (Phase 0.5: Template Engine)
    |
    v
Milestone 3 (Phase 1: Web Platform)
    |
    v
Milestone 4 (Gate Review)
    |
    +---> Milestone 5 (Phase 2: iOS) --+
    |                                   |
    +---> Milestone 6 (Phase 3: Android) --+--> Milestone 7 (Phase 4: Jasonpedia)
                                                |
                                                v
                                        Milestone 8 (Phase 5: Ecosystem)
```

Milestones 5 and 6 run in parallel. Milestone 7 starts when at least the web renderer is stable (can begin URL auditing during Phases 2/3). Milestone 8 can begin documentation work during Phases 2/3.

## Risk Mitigations

| Risk | Mitigation |
|---|---|
| Template engine takes 4+ weeks | Time-box to 3 weeks; cut `#let`/`#concat`/`#merge` if behind |
| Automated reviewers produce 50+ comments | Max 3 review cycles (D6); dismiss false positives with explanation |
| iOS UIHostingConfiguration sizing bugs | Known Apple issue; fallback to manual cell sizing if needed |
| External APIs in Jasonpedia are dead | Local test fixtures (D7); self-host mock APIs |
| Schema changes discovered during web implementation | Gate Review exists for this; changes documented and propagated |
| Single maintainer burnout | Ship web first to attract contributors; Android deferred to v1.1 |
| JSEP doesn't handle regex in conditions | JSEP has a regex plugin; add it to the evaluator |

## References

- [Roadmap Plan](./2026-02-26-feat-jasonette-revival-roadmap-plan.md)
- [SwiftUI/Compose Brainstorm](../brainstorms/2026-02-26-swiftui-compose-ui-framework-brainstorm.md)
- [JSEP — JavaScript Expression Parser](https://github.com/EricSmekens/jsep) (corrected URL)
- [Vite Library Mode](https://vitejs.dev/guide/build.html#library-mode)
- [Vitest](https://vitest.dev/)
- [UIHostingConfiguration (Apple)](https://developer.apple.com/documentation/swiftui/uihostingconfiguration)
- [Jetpack Compose LazyColumn](https://developer.android.com/develop/ui/compose/lists)
