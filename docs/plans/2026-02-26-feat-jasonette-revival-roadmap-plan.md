---
title: "Jasonette Revival Roadmap"
type: feat
date: 2026-02-26
deepened: 2026-02-26
---

# Jasonette Revival Roadmap

## Enhancement Summary

**Deepened on:** 2026-02-26
**Research agents used:** Architecture Strategist, Security Sentinel, Performance Oracle, Code Simplicity Reviewer, Agent-Native Reviewer, Best Practices (Sandbox Research + OSS Revival), Framework Docs Researcher

### Key Improvements

1. **Template engine architecture solidified** — JSEP + custom AST walker recommended over `Function()` / full JS engines for expression evaluation. Concrete code patterns and security layers documented.
2. **Security architecture hardened** — 18 findings across template sandboxing, $agent bridge permissions, SSRF protection, OAuth PKCE, iOS Privacy Manifest, prototype pollution prevention, and expression complexity limits.
3. **Performance architecture specified** — Singleton JS engine per app, expression compilation cache, pre-evaluate `#each` before render, avoid UIHostingController/ComposeView in scrolling list cells, parallel mixin fetch.
4. **Phase structure simplified** — Reviewers recommend merging from 7 phases to 4, cutting Android from v1.0, dropping playground/VS Code extension/DevTools panel from initial scope.
5. **Agent-native design gaps identified** — 13 of 15 capabilities have no programmatic path; CLI tool should move to Phase 1 with `--format json` on all commands.
6. **OSS revival playbook added** — 90-day launch strategy, GitHub org reclamation guidance, governance templates, funding realistic expectations.
7. **Action concurrency model needed** — Unspecified whether actions run serially or concurrently; needs formal definition before implementation.

### New Considerations Discovered

- Template conformance test suite should be the single source of truth (not prose spec)
- `$session` should move from Tier 2 to Tier 1 (networking depends on it)
- Phase 0.5 budget should be 2-3 weeks (not 1 week) — template engine is highest-risk component
- `$agent.inject` (arbitrary JS injection into web containers) is effectively RCE and should be removed or heavily restricted
- iOS Privacy Manifest required since Spring 2024 — must declare data collection and tracking domains
- **iOS:** Hybrid UICollectionView + UIHostingConfiguration (SwiftUI cells with UIKit recycling) — see [brainstorm](../brainstorms/2026-02-26-swiftui-compose-ui-framework-brainstorm.md)
- **Android:** Jetpack Compose with LazyColumn (native recycling, no RecyclerView needed)
- **Template engine:** TypeScript first, shared Rust core later via UniFFI/wasm
- "3+ maintainers before v1.0" is a deadlock condition — ship with 1 committed maintainer, recruit via shipped product

---

## Overview

Jasonette is a pioneering JSON-to-native-app framework created by Ethan (`@gliechtenstein`) in October 2016. The maintainer disappeared in June 2018, leaving the project abandoned. The iOS repo earned 5,200 stars and Android 1,600 stars before going silent.

This plan assesses the current state of all four subprojects (iOS, Android, Web, Jasonpedia) and lays out a phased roadmap to revive the project on modern platforms.

## Current State Assessment

### What Exists

| Subproject | Language | LOC | Last Active | Status |
|---|---|---|---|---|
| **JASONETTE-iOS** | 100% Objective-C | ~14,600 | July 2021 (README redirect) | Dead |
| **JASONETTE-Android** | 100% Java | ~12,700 | July 2021 (README redirect) | Dead |
| **Jasonette-Web** | Vanilla JS | ~1,033 | Jan 2018 (code), Apr 2023 (deps) | Dead |
| **Jasonpedia** | JSON examples | 100 files | ~2018 | Stale but valuable |

### Critical Blockers (Cannot Build/Ship As-Is)

**iOS:**
- Uses `UIWebView` in `JasonHtmlComponent.m` and `Jason.h` — **rejected by App Store since April 2020**
- Deployment target iOS 9.3 (Podfile says iOS 8.0) — current requirement is Xcode 16 / iOS 18 SDK
- CocoaPods enters **read-only mode December 2, 2026** — 42 pods need SPM migration or replacement
- Several dependencies are personal forks from `@gliechtenstein` that may disappear
- SDWebImage 3.8.1 (current: 5.x), AFNetworking 3.1.0 (replaced by URLSession)

**Android:**
- `jcenter()` repository **shut down August 15, 2024** — builds will fail immediately
- `compileSdkVersion 28` / `targetSdkVersion 28` — Google Play requires **API 35** as of August 2025
- Android Gradle Plugin 3.5.1 / Gradle 5.6.2 — current is AGP 9.0.1 / Gradle 8.x (5+ years of breaking changes)
- `commons-lang:20030203.000129` — a dependency from **2003**
- J2V8 (V8 JavaScript engine) is in maintenance mode

**Web:**
- Uses `Function()` constructor for dynamic code evaluation — security vulnerability
- Gulp v3.9.1 (released 2015) — current is v5.x
- External CDN dependencies (cell.js, st.js) with no version pinning or SRI hashes
- No module system, no minification, no tests

### What IS Worth Preserving

1. **The JSON Schema/Protocol** — The `$jason` markup language is the real innovation. 100 example files in Jasonpedia document it thoroughly.
2. **The Architecture Concepts** — Component system, action system, template engine, mixin system are well-designed patterns.
3. **The Jasonpedia Examples** — 100 JSON files covering views, actions, templates, web containers, and core features serve as both specification and test suite.

### The Jasonelle Fork

A community fork at [github.com/jasonelle](https://github.com/jasonelle/jasonelle) exists (71 stars, maintained by `@clsource`). It pivoted from "JSON to native" to "web app wrapper" and requires a commercial license for production. It is effectively a different product with minimal community traction.

### Research Insights: OSS Revival Context

**GitHub Org Reclamation:**
- GitHub's dormant account policy requires 1+ year of inactivity, but reclamation is slow and uncertain
- Recommendation: Start under a new org (e.g., `jasonette-dev`), pursue reclamation in parallel
- If reclamation fails, the code and brand value transfers via stars/SEO

**90-Day Revival Playbook (from OSS research):**
- Days 1-30: Fork, clean up, get CI green, write CONTRIBUTING.md, publish "Jasonette is Back" blog post
- Days 31-60: Ship the web renderer (smallest, fastest to show progress), merge first external PR
- Days 61-90: Ship iOS beta, announce on HN (best timing: Tuesday/Wednesday 10am ET), apply to GitHub Sponsors

**Funding Realistic Expectations:**
- GitHub Sponsors: $200-500/month for a niche OSS project in year 1
- Corporate sponsors unlikely until real adoption exists
- Focus on developer goodwill, not revenue, for the first year

### Competing Projects in 2026

| Framework | Stars | Approach | Platforms | Backed By |
|---|---|---|---|---|
| **DivKit** | 2,600 | JSON to native (closest to Jasonette) | iOS/Android/Web | Yandex |
| **Hyperview** | 1,700 | XML (HXML) to native via React Native | iOS/Android | Instawork |
| **Nativeblocks** | N/A | Commercial SDUI platform | iOS/Android/RN | Commercial |

Server-Driven UI (SDUI) — the pattern Jasonette pioneered — is now mainstream at Airbnb, Google, and others.

---

## Strategic Decision: Revive vs. Rewrite

### Recommendation: Rewrite with the original JSON schema as the specification

**Why not patch the existing code:**
- Every single source file on iOS needs changes (UIWebView, deployment target, ObjC patterns)
- Every single build file on Android needs changes (jcenter, AGP, SDK target)
- The effort to patch is equivalent to rewriting, but with the burden of understanding legacy code
- The dependency graph is full of dead/abandoned libraries

**Why rewrite rather than just adopt DivKit:**
- Jasonette's JSON schema is simpler and more accessible than DivKit's
- The `$jason` protocol has existing documentation, 100 examples, and brand recognition (5,200 stars)
- DivKit requires Yandex's toolchain; Jasonette was intentionally minimal
- The vision of "describe an entire app in a single JSON file fetched from a URL" remains compelling

**What to preserve from the original:**
- The `$jason` JSON schema as the specification (head/body/sections/items/actions pattern)
- The Jasonpedia examples as both spec and test suite
- The project name and brand identity
- The MIT license

---

## Proposed Solution: Phased Revival Roadmap

### Phase 0: Foundation (Weeks 1-2)

**Goal:** Establish project infrastructure before writing any app code.

#### 0.1 — Fork and Organize

- [ ] Create a new GitHub organization (e.g., `jasonette-dev` or reclaim `Jasonette`)
- [ ] Fork the four repos into the new org
- [ ] Write a project charter: mission, governance model, licensing (MIT)
- [ ] Set up communication: GitHub Discussions, Discord, or similar
- [ ] Announce the revival on the original repos' issue trackers and relevant communities

#### 0.2 — Formalize the JSON Schema

- [ ] Extract the `$jason` protocol from Jasonpedia examples into a formal specification
- [ ] Document every element: `head`, `body`, `header`, `footer`, `sections`, `items`, `layers`
- [ ] Document every component: `label`, `button`, `image`, `textfield`, `textarea`, `html`, `map`, `slider`, `switch`, `space`
- [ ] Audit every `.m` and `.java` action file to produce the complete action catalogue:
  - **Core:** `$render`, `$reload`, `$href`, `$lambda`/`trigger`, `$return.success`/`$return.error`
  - **Networking:** `$network.request` (GET/POST/PUT/DELETE, multipart, headers, auth)
  - **State:** `$set`, `$get`, `$cache.*`, `$session.*`, `$global.*`
  - **UI:** `$util.alert`, `$util.banner`, `$util.toast`, `$util.picker`, `$util.datepicker`, `$util.share`
  - **Media:** `$media.camera`, `$media.picker`, `$audio.*`, `$snapshot`
  - **Device:** `$geo.*`, `$vision.*`, `$addressbook`
  - **Async:** `$timer.*`, `$websocket.*`
  - **Auth:** `$oauth.*` (client_id, client_secret, token flows)
  - **Code:** `$script.*` (inline JavaScript evaluation)
  - **Agent:** `$agent.request`, `$agent.response` (native-to-webview bridge)
  - **Debug:** `$log.*`, `$convert.*`
- [ ] Mark each action as **Tier 1 (v1.0)**, **Tier 2 (v1.1)**, or **Tier 3 (v1.2)**:
  - **Tier 1 (v1.0):** `$render`, `$reload`, `$href`, `$lambda`/`trigger`/`$return`, `$network.request`, `$set`/`$get`, `$cache.*`, `$util.*`, `$timer.*`, `$log.*`
  - **Tier 2 (v1.1):** `$media.*`, `$geo.*`, `$audio.*`, `$agent.*`, `$session.*`, `$global.*`, `$convert.*`, `$snapshot`, `$addressbook`
  - **Tier 3 (v1.2):** `$oauth.*`, `$websocket.*`, `$push.*`, `$script.*`, `$vision.*`
- [ ] Document the **action execution model** formally:
  - Action chaining via `success` and `error` continuation handlers
  - Named action calls via `$lambda` / `trigger` with arguments and return values
  - Return value propagation via `$return.success` and `$return.error`
  - Conditional branching within action chains (`{{#if}}` in action definitions)
- [ ] Document **lifecycle hooks** and when each fires:
  - `$load` — fires once when screen first renders
  - `$show` — fires each time the screen becomes visible (including back navigation)
  - `$foreground` — fires when app returns from background
  - `$background` — fires when app enters background
  - `$pull` — fires on pull-to-refresh gesture
- [ ] Document the template engine (more complex than Mustache):
  - Variable binding: `{{$jason.name}}`
  - Array iteration: `{{#each items}}...{{/each}}`
  - Conditionals: `{{#if condition}}...{{#elseif}}...{{#else}}...{{/if}}`
  - Full JavaScript expressions: `{{Math.floor($jason.temp)}}`, `{{JSON.stringify(data)}}`
  - Regular expressions in conditions: `{{#if /pattern/.test($jason.url)}}`
  - Property access with operators: `{{$jason && 'key' in $jason}}`
  - The `@` mixin operator for remote JSON inclusion
  - `$document` for local mixin references
  - **This is effectively a sandboxed JS expression evaluator, not simple string interpolation**
- [ ] Document the **style class system**: `head.styles` defines named style classes, components reference them via `"class": "bold padded"`
- [ ] Document the `$href` navigation options fully:
  - `"transition": "modal"` / `"fullscreen"` / push (default)
  - `"view": "jason"` (default) / `"web"` / `"app"`
  - `"fresh": true` — force reload, bypass cache
  - `"preload": { "background": "#fff" }` — loading screen during fetch
  - Tab-based navigation configuration
- [ ] Document the **app configuration contract** replacing `settings.plist`:
  - Root JSON URL, OAuth credentials, debug mode, loading/launch behavior
  - Propose `jasonette.config.json` as cross-platform config format
- [ ] Publish as a versioned spec (`$jason` Schema v2.0)
- [ ] Create a JSON Schema (json-schema.org) file for editor autocompletion and validation

#### Research Insights: Schema & Architecture

**Template Conformance Test Suite (Architecture Review):**
- The Jasonpedia JSON files should be promoted to **the** specification, not just examples
- Create a formal conformance test suite: `input JSON` → `expected output structure` for every Jasonpedia file
- Every platform implementation runs this suite in CI — if it passes, the platform is conformant
- This prevents spec drift between platforms far better than prose documentation

**Action Concurrency Model (Architecture Review — Gap):**
- The plan does not specify whether actions run serially or concurrently
- Original Jasonette appears to run actions serially within a chain but lacks formal spec
- Recommendation: Define explicitly — serial within a chain, concurrent across independent triggers
- Document cancellation semantics: what happens to a running `$timer` when `$href` navigates away?

**$session Should Be Tier 1 (Architecture Review):**
- `$network.request` (Tier 1) depends on session/cookie management for any authenticated API
- Without `$session` in Tier 1, the web renderer can't demo login flows — the most common real-world pattern
- Move `$session.*` from Tier 2 to Tier 1

**Module Boundaries (Architecture Review):**
- Define clean module interfaces before coding: Template Engine, Component Registry, Action Dispatcher, State Store, Navigation Router
- Each module should be testable in isolation with mock dependencies
- This enables parallel development by multiple contributors

#### 0.3 — Set Up CI/CD

- [ ] GitHub Actions for iOS (xcodebuild), Android (Gradle), and Web (Node)
- [ ] Automated testing pipeline (even if tests are sparse initially)
- [ ] Linting: SwiftLint (iOS), ktlint (Android), ESLint (Web)
- [ ] Dependabot for dependency updates

**Deliverable:** Published `$jason` schema spec with complete action catalogue, tiered feature list, and formal action execution model. Empty but building project skeletons on all three platforms.

---

### Phase 0.5: Template Engine Prototype (Week 3) ✅ COMPLETED

**Goal:** The template engine is the highest-risk shared component. Prototype it before building any UI.

- [x] Implement in TypeScript (will become the Web version; patterns ported to Swift/Kotlin later)
- [x] Must handle: `{{var}}`, `{{#each}}`, `{{#if}}`/`{{#elseif}}`/`{{#else}}`, full JS expressions, regex conditions
- [x] Implement sandboxed expression evaluation:
  - Use a restricted JavaScript context (no access to `window`, `document`, `fetch`, or platform APIs)
  - Only `$jason` data context, `Math`, `JSON`, `String`, `Array`, `Object` builtins available
  - No side effects allowed in expressions
- [x] Implement the `@` mixin operator (remote JSON inclusion with recursive resolution)
  - Maximum recursion depth (default: 5) to prevent circular mixin references
  - Cache fetched mixins in memory
  - Timeout and error handling for failed remote fetches
- [x] Implement `$document` local mixin references
- [x] Validate against **every** Jasonpedia template example (`template/*.json`)
- [x] Validate expression evaluation against action examples (`action/lambda/*.json`, `action/script/*.json`)

**Deliverable:** `@jasonette/template-engine` package passing all Jasonpedia template and expression tests.

#### Research Insights: Template Engine Architecture

**Recommended Architecture: JSEP + Custom AST Walker (Sandbox Research):**

The template engine should use a two-layer design:
1. **Template Parser** — handles `{{...}}`, `{{#each}}`, `{{#if}}`, `@` mixins, `$document` refs
2. **Expression Evaluator** — evaluates the JavaScript-like expressions inside `{{ }}`

For the Expression Evaluator, use [JSEP](https://github.com/EricSmekworthy/jsep) (JavaScript Expression Parser):
- Parses expressions into an AST without executing them
- 3KB minified, zero dependencies, works in all environments
- Supports: member access, binary operators, unary operators, function calls, ternary, array/object literals

Then walk the AST with a custom evaluator that enforces security:

```typescript
// Simplified AST walker pattern
function evaluate(node: jsep.Expression, context: Record<string, any>): any {
  switch (node.type) {
    case 'Identifier':
      return context[node.name]; // Only resolve from $jason context
    case 'MemberExpression':
      return evaluate(node.object, context)?.[node.property.name];
    case 'BinaryExpression':
      return applyOperator(node.operator, evaluate(node.left, context), evaluate(node.right, context));
    case 'CallExpression':
      const fn = SAFE_FUNCTIONS[node.callee.name]; // Allowlist only
      if (!fn) throw new Error(`Blocked function: ${node.callee.name}`);
      return fn(...node.arguments.map(a => evaluate(a, context)));
    // ... other node types
  }
}
```

**Security Layers (Sandbox Research + Security Review):**
- **AST Validation:** Reject nodes with `type: 'AssignmentExpression'` (no side effects)
- **Function Allowlist:** Only `Math.*`, `JSON.stringify`, `JSON.parse`, `parseInt`, `parseFloat`, `String`, `Number`, `Boolean`, `Array.isArray`, `Object.keys`
- **Property Blocklist:** Block access to `__proto__`, `constructor`, `prototype` on any object
- **Complexity Limits:** Max AST depth of 20 nodes, max 50 nodes per expression, 10ms timeout
- **No `eval`, `Function`, `setTimeout`, `setInterval`** — these never appear in the AST because JSEP doesn't parse them as language constructs

**Performance (Sandbox Research):**
- JSEP parsing: ~500K expressions/sec
- AST walking: ~200K evaluations/sec
- With LRU expression cache (key: expression string, value: parsed AST): 1M+ lookups/sec for repeated expressions
- This is critical for `#each` loops where the same expression evaluates against different items

**Why NOT use JavaScriptCore/QuickJS/V8 for the expression evaluator:**
- Full JS engines allow `eval()`, `Function()`, prototype mutation — hard to sandbox completely
- They're heavyweight for simple property access and math (most Jasonette expressions are `$jason.name` or `$jason.count > 0`)
- JSEP + AST walker is 3KB vs 500KB+ for a JS engine
- However, `$script.*` (Tier 3) will need a full JS engine — keep that separate from expression evaluation

**Budget: 2-3 Weeks (Architecture Review):**
- The original 1-week estimate is too aggressive for the highest-risk shared component
- Template engine touches every feature: rendering, conditionals, loops, mixins, actions
- Edge cases: nested `#each` with `#if`, mixin recursion, circular references, malformed expressions
- Build the conformance test suite first, then implement until all tests pass

---

### Phase 1: Web Platform (Weeks 4-7) ✅ COMPLETED

**Goal:** Ship a working web renderer first — it's the smallest codebase and fastest iteration cycle.

**Why Web first:**
- Only 1,033 lines of source — smallest surface area
- Fastest feedback loop (no Xcode/Gradle builds)
- Can serve as the reference implementation for the spec
- Useful immediately as a preview tool for JSON markup

#### 1.1 — Modern Web Rewrite

- [x] Rewrite in TypeScript with ES modules
- [x] Replace cell.js with vanilla `document.createElement`
- [x] Integrate the `@jasonette/template-engine` from Phase 0.5
- [x] Use Vite for bundling in library mode (ESM + CJS + UMD)
- [x] Add proper `<script type="module">` support
- [x] npm-install all dependencies (no external CDN)
- [x] Add unit tests (Vitest)

#### 1.2 — Feature Parity

- [x] Render Jasonpedia view examples correctly (integration tests)
- [x] Template engine integration for mixin system
- [x] Implement all components: label, button, image, textfield, textarea, html, slider, space, switch, map (stub)
- [x] Implement layouts: vertical, horizontal, nested
- [x] Implement header, footer (tabs + input), layers
- [x] Implement **Tier 1 actions**: `$render`, `$reload`, `$network.request`, `$set`/`$get`, `$cache.*`, `$util.alert`/`$util.banner`/`$util.toast`, `$timer.*`, `$log.*`
- [x] Implement action chaining (success/error handlers) and `$lambda`
- [x] Implement `$href` navigation as SPA with History API
- [x] Implement lifecycle hooks: `$load`, `$show`, `$foreground`, `$pull`

#### 1.3 — Developer Experience

- [x] Live reload dev server (`jasonette serve`)
- [x] JSON validation with helpful error messages (`jasonette validate`)
- [x] `--format json` flag for CLI output

**Results:** 58 tests, 49KB ESM (13KB gzipped), 10 components, 15 actions, 3 lifecycle hooks.

**Deliverable:** `@jasonette/web` npm package that renders `$jason` JSON in the browser.

#### Research Insights: Web Platform

**Build Tooling (Framework Docs Research):**
- Use **Vite** in library mode for the npm package build (outputs ESM + CJS + UMD)
- Use **Vitest** for testing (same config as Vite, fast, supports TypeScript natively)
- Bundle size target: <50KB gzipped for the core renderer (no heavy deps)

**SPA Navigation (Framework Docs Research):**
- Use `History.pushState()` / `popstate` event for push/pop navigation
- Modal transitions: CSS `dialog` element (native HTML, no library needed)
- Tab navigation: persistent bottom bar with `data-active` state, swap content area
- Handle browser back button properly — users expect it to "go back" in Jasonette navigation

**Simplicity Review — Cut from v1.0:**
- Drop `npx create-jasonette` scaffold command — a README example is sufficient
- Drop Browser DevTools extension — use `console.log` and the built-in `$log` action
- Keep live reload dev server and JSON validation — these are high-value, low-effort

**Agent-Native Review — CLI in Phase 1:**
- Add a CLI tool (`jasonette validate app.json`, `jasonette serve app.json`) in this phase, not Phase 5
- Add `--format json` to all CLI commands so agents can consume output
- Add `jasonette render app.json --output structured` to get render tree as JSON
- This makes the web renderer immediately useful for CI/CD validation and agent workflows

**Performance (Performance Oracle):**
- Use `requestAnimationFrame` batching for DOM updates during `$render`
- Implement virtual scrolling for long `sections/items` lists (>100 items)
- Pre-evaluate `#each` template expressions once, then apply to each item (don't re-parse per item)

---

### Gate Review (Week 7) ✅ COMPLETED

Before starting native development, verify:

- [x] The `$jason` schema spec is stable (codified in `spec/schema/`)
- [x] The template engine passes all Jasonpedia template and expression examples (140 tests)
- [x] All Jasonpedia view examples render correctly on the web (integration tests)
- [x] The action execution model (chaining, lambda, return, lifecycle hooks) is formally documented
- [x] The action tier list (v1.0 / v1.1 / v1.2) is finalized

---

### Phase 2: iOS Platform (Weeks 8-15) — COMPLETED

**Goal:** Native iOS app shell that renders `$jason` JSON using modern Swift.

**Status:** Completed 2026-02-28 — PR #4

#### 2.1 — New Xcode Project

- [ ] Create new project in Swift, minimum deployment target **iOS 16**
- [ ] Use **Swift Package Manager** exclusively (zero CocoaPods)
- [ ] Structure: `Core/`, `Components/`, `Actions/`, `Services/`, `Helpers/`
- [ ] **UI framework:** Hybrid — `UICollectionView` + `CompositionalLayout` + `DiffableDataSource` for the scrolling/recycling engine. `UIHostingConfiguration` renders SwiftUI views as cell content. All visible component UI is written in SwiftUI. Navigation uses `UINavigationController`.
- [ ] Set up the JSON fetching and caching layer using `URLSession`
- [ ] Add `PrivacyInfo.xcprivacy` (iOS Privacy Manifest — required since Spring 2024)

#### 2.2 — Core Framework

- [ ] Template engine (port JSEP + AST walker patterns from TypeScript to Swift)
  - Use `JavaScriptCore` (single `JSContext` per app) for `$script.*` only; expression evaluation uses native Swift AST walker
  - Long-term: replace with shared Rust core via UniFFI
- [ ] Component registry and factory (protocol-oriented Swift) — maps JSON type strings to SwiftUI views
- [ ] `UICollectionView` rendering engine:
  - `CompositionalLayout` for section-based layouts (vertical, horizontal, grid)
  - `DiffableDataSource` for animated updates when server pushes new JSON
  - `UIHostingConfiguration` wrapping SwiftUI component views as cell content
  - Always set `.id(item.hashValue)` on root SwiftUI view to prevent reuse identity bugs
  - Lift `@State` out of cell views into external observable store
- [ ] Action dispatcher (Swift protocols + structured concurrency)
- [ ] Navigation system — full `$href` options:
  - `UINavigationController` push (default), `present()` for modal/fullscreen
  - `"view": "web"` opens SFSafariViewController, `"view": "app"` opens `UIApplication.open()`
  - `"preload"` shows placeholder during JSON fetch
  - Tab-based navigation via `UITabBarController`
  - No `NavigationLink` — handle cell selection via UICollectionView delegate
- [ ] State management (`$get`, `$set`, variables, `$global`)
- [ ] Action execution engine: success/error chaining, `$lambda`/`trigger`, `$return`
- [ ] Lifecycle hooks: `$load`, `$show` (viewDidAppear), `$foreground` (UIScene willEnterForeground), `$pull` (UIRefreshControl)
- [ ] Style class system: parse `head.styles`, resolve `"class"` references on components
- [ ] Error handling: built-in error screen when JSON is invalid or URL unreachable
- [ ] App configuration: read `jasonette.config.json` for root URL, debug mode, launch screen behavior
- [ ] ATS (App Transport Security): require HTTPS by default, document exception configuration

#### 2.3 — Components (SwiftUI views rendered via UIHostingConfiguration)

| Old (ObjC) | New (SwiftUI) | Notes |
|---|---|---|
| `JasonLabelComponent` | `LabelComponent` | SwiftUI `Text` |
| `JasonImageComponent` | `ImageComponent` | SwiftUI `AsyncImage` or Kingfisher/Nuke (SPM) |
| `JasonButtonComponent` | `ButtonComponent` | SwiftUI `Button` |
| `JasonTextfieldComponent` | `TextFieldComponent` | SwiftUI `TextField` |
| `JasonTextareaComponent` | `TextAreaComponent` | SwiftUI `TextEditor` |
| `JasonHtmlComponent` | `HtmlComponent` | **WKWebView** via `UIViewRepresentable` (replaces banned UIWebView) |
| `JasonMapComponent` | `MapComponent` | SwiftUI `Map` (MapKit) |
| `JasonSliderComponent` | `SliderComponent` | SwiftUI `Slider` |
| `JasonSwitchComponent` | `SwitchComponent` | SwiftUI `Toggle` |
| `JasonSpaceComponent` | `SpaceComponent` | SwiftUI `Spacer` |

#### 2.4 — Actions (replace all ObjC actions)

**Tier 1 (v1.0):**
- [ ] `$network.request` — URLSession with async/await (GET/POST/PUT/DELETE, multipart, custom headers)
- [ ] `$render` / `$reload` — View update system
- [ ] `$href` — Full navigation (push, modal, fullscreen, web, app, tabs, preload)
- [ ] `$lambda` / `trigger` / `$return` — Action composition and named action calls
- [ ] `$util.*` — alert, banner, toast, picker, datepicker, share
- [ ] `$set` / `$get` — Local state management
- [ ] `$cache.*` — UserDefaults or FileManager
- [ ] `$timer.*` — Swift Timer / Task.sleep
- [ ] `$log.*` — os_log or print for debug output

**Tier 2 (v1.1):**
- [ ] `$media.*` — PHPickerViewController (replaces UIImagePickerController), AVFoundation
- [ ] `$geo.*` — CoreLocation (request permission on first use, deny routes to `error` handler)
- [ ] `$audio.*` — AVAudioPlayer / AVAudioRecorder
- [ ] `$agent.*` — WKWebView bidirectional messaging bridge (native-to-web and web-to-native)
- [ ] `$session.*` — HTTP session persistence
- [ ] `$global.*` — Cross-screen global state
- [ ] `$convert.*` — Data format conversion
- [ ] `$snapshot` — Screenshot capture
- [ ] `$addressbook` — CNContactStore (replaces deprecated APAddressBook)

**Tier 3 (v1.2):**
- [ ] `$oauth.*` — ASWebAuthenticationSession (replaces old OAuth flow)
- [ ] `$websocket.*` — URLSessionWebSocketTask
- [ ] `$push.*` — UNUserNotificationCenter + APNs
- [ ] `$script.*` — JavaScriptCore sandboxed execution
- [ ] `$vision.*` — VisionKit (barcode scanning)

#### 2.5 — Testing

- [ ] Run every Jasonpedia example JSON and verify rendering
- [ ] XCTest unit tests for parser, template engine, component factory
- [ ] UI tests for navigation and interaction flows
- [ ] Snapshot tests for visual regression

**Deliverable:** A Swift-based iOS app that renders `$jason` JSON natively, submittable to the App Store.

#### Research Insights: iOS Platform

**UI Framework Decision (Updated per brainstorm 2026-02-26):**
- **Hybrid approach:** `UICollectionView` + `CompositionalLayout` + `DiffableDataSource` for scrolling/recycling; `UIHostingConfiguration` for SwiftUI cell content
- This is the pattern used by Duolingo (ReactiveCollectionsKit) and HEMA (58 SDUI components in production)
- `UIHostingConfiguration` (iOS 16+) gives proper cell recycling with SwiftUI views — avoids `UIHostingController` sizing/performance issues
- Key rule: always set `.id(item.id)` on root SwiftUI view inside `UIHostingConfiguration` to prevent reuse identity bugs
- No `NavigationLink` inside cells — handle selection via UICollectionView delegate, push to `UINavigationController`
- `@State` resets on cell recycle — lift state to external observable store

**JavaScriptCore Sandboxing (Framework Docs Research):**
- Create a single `JSContext` per app instance (not per expression evaluation)
- Remove all global objects: `JSContext().globalObject.setValue(nil, forProperty: "setTimeout")` etc.
- Inject only the `$jason` data context before each evaluation
- Use `JSContext.evaluateScript(_:withSourceURL:)` for better error reporting
- Set `exceptionHandler` to catch and report template expression errors gracefully

**iOS Privacy Manifest (Security Review — Critical):**
- Required since Spring 2024 for App Store submission
- Must declare: data collection types, tracking domains, required reason APIs
- Jasonette uses several "required reason" APIs: `UserDefaults` (state), `NSURLSession` (networking), `NSFileManager` (cache)
- Add `PrivacyInfo.xcprivacy` file to the Xcode project in Phase 2.1

**$agent Bridge Security (Security Review):**
- `WKWebView` `userContentController.add(self, name:)` for native-to-web messaging
- `WKScriptMessageHandler` for web-to-native messaging
- **Per-agent action allowlist**: each `$agent` instance should declare which native actions it can trigger
- Block `$agent.inject` (arbitrary JS injection) — this is RCE. Replace with a message-passing protocol only.

**OAuth Must Use PKCE (Security Review):**
- `ASWebAuthenticationSession` with PKCE (Proof Key for Code Exchange) is the modern standard
- Never store `client_secret` in the app binary — PKCE eliminates the need for it
- The original `settings.plist` with `client_secret` is a security antipattern

**Concurrency (Performance Oracle):**
- Use Swift structured concurrency (`async/await`, `Task`, `TaskGroup`) for action execution
- Action chains should run on a dedicated `Actor` to prevent data races on shared state
- `$timer` should use `Task.sleep(nanoseconds:)` not `Timer.scheduledTimer` (cancellable, no run loop dependency)

---

### Phase 3: Android Platform (Weeks 8-15, parallel with iOS)

**Goal:** Native Android app shell that renders `$jason` JSON using modern Kotlin.

#### 3.1 — New Android Studio Project

- [ ] Create new project in **Kotlin**, minimum SDK **26** (Android 8), target SDK **35**
- [ ] **AGP 9.x**, **Gradle 8.x**, **Java 17**
- [ ] Use **mavenCentral()** and **google()** only (zero jcenter)
- [ ] Structure: `core/`, `components/`, `actions/`, `services/`, `helpers/`
- [ ] **UI framework:** Jetpack Compose with `LazyColumn` / `LazyRow` for all list rendering. No RecyclerView. Compose's `LazyColumn` recycles items natively.

#### 3.2 — Core Framework

- [ ] Template engine (port JSEP + AST walker patterns from TypeScript to Kotlin)
  - Use **QuickJS** for `$script.*` only; expression evaluation uses native Kotlin AST walker
  - Long-term: replace with shared Rust core via UniFFI
- [ ] Component registry — maps JSON type strings to `@Composable` functions
- [ ] Compose rendering engine:
  - `LazyColumn` / `LazyRow` for lists (native item recycling)
  - Dynamic composable dispatch via `when(component.type)` — no `AnyView` equivalent needed
- [ ] Action dispatcher (Kotlin coroutines for async actions)
- [ ] Navigation system — full `$href` options:
  - Compose Navigation or Activity-based push (default), dialog/fullscreen for modal
  - `"view": "web"` opens Custom Tabs, `"view": "app"` opens Intent
  - `"preload"` shows placeholder during JSON fetch
  - Tab-based navigation via Compose `NavigationBar`
- [ ] State management (`$get`, `$set`, variables, `$global`)
- [ ] Action execution engine: success/error chaining, `$lambda`/`trigger`, `$return`
- [ ] Lifecycle hooks: `$load`, `$show` (onResume), `$foreground` (Lifecycle.Event.ON_START), `$pull` (Compose `pullToRefresh`)
- [ ] Style class system: parse `head.styles`, resolve `"class"` references on components
- [ ] Error handling: built-in error screen when JSON is invalid or URL unreachable
- [ ] App configuration: read `jasonette.config.json` for root URL, debug mode, launch screen behavior
- [ ] Runtime permissions: automatically request on first use of permission-gated actions, denial routes to `error` handler

#### 3.3 — Components (Jetpack Compose)

| Old (Java) | New (Compose) | Notes |
|---|---|---|
| `JasonLabelComponent` | `LabelComponent` | Compose `Text` |
| `JasonImageComponent` | `ImageComponent` | Coil (Kotlin-first, coroutine-native) with Compose `AsyncImage` |
| `JasonButtonComponent` | `ButtonComponent` | Compose `Button` |
| `JasonTextfieldComponent` | `TextFieldComponent` | Compose `TextField` |
| `JasonTextareaComponent` | `TextAreaComponent` | Compose `TextField` (multi-line) |
| `JasonHtmlComponent` | `HtmlComponent` | Android `WebView` via `AndroidView` composable |
| `JasonMapComponent` | `MapComponent` | Google Maps Compose SDK |
| `JasonSliderComponent` | `SliderComponent` | Compose `Slider` |
| `JasonSwitchComponent` | `SwitchComponent` | Compose `Switch` |
| `JasonSpaceComponent` | `SpaceComponent` | Compose `Spacer` |

#### 3.4 — Actions (replace all Java actions)

**Tier 1 (v1.0):**
- [ ] `$network.request` — OkHttp 4.12+ with Kotlin coroutines (GET/POST/PUT/DELETE, multipart, custom headers)
- [ ] `$render` / `$reload` — View update system
- [ ] `$href` — Full navigation (push, modal, fullscreen, web via Custom Tabs, app via Intent, tabs, preload)
- [ ] `$lambda` / `trigger` / `$return` — Action composition and named action calls
- [ ] `$util.*` — MaterialAlertDialog, Snackbar, DatePickerDialog, ShareSheet
- [ ] `$set` / `$get` — Local state management
- [ ] `$cache.*` — SharedPreferences or DataStore
- [ ] `$timer.*` — Kotlin coroutines `delay()`
- [ ] `$log.*` — Timber or Log for debug output

**Tier 2 (v1.1):**
- [ ] `$media.*` — ActivityResult API + CameraX (replaces dead CWAC Camera)
- [ ] `$geo.*` — FusedLocationProviderClient (runtime permission, deny routes to `error`)
- [ ] `$audio.*` — MediaPlayer / MediaRecorder
- [ ] `$agent.*` — Android WebView `addJavascriptInterface` bridge (native-to-web and web-to-native)
- [ ] `$session.*` — HTTP session persistence (OkHttp CookieJar)
- [ ] `$global.*` — Cross-screen global state
- [ ] `$convert.*` — Data format conversion
- [ ] `$snapshot` — View screenshot capture
- [ ] `$addressbook` — ContactsContract

**Tier 3 (v1.2):**
- [ ] `$oauth.*` — Custom Tabs OAuth flow
- [ ] `$websocket.*` — OkHttp WebSocket
- [ ] `$push.*` — Firebase Cloud Messaging 24.x
- [ ] `$script.*` — QuickJS sandboxed execution
- [ ] `$vision.*` — ML Kit Barcode Scanning (replaces deprecated play-services-vision)

#### 3.5 — Testing

- [ ] Run every Jasonpedia example JSON and verify rendering
- [ ] JUnit + Espresso for unit and UI tests
- [ ] Robolectric for faster component tests
- [ ] Screenshot tests for visual regression

**Deliverable:** A Kotlin-based Android app that renders `$jason` JSON natively, publishable on Google Play.

#### Research Insights: Android Platform

**UI Framework Decision (Updated per brainstorm 2026-02-26):**
- **Jetpack Compose with `LazyColumn`** — `LazyColumn` recycles items natively, no RecyclerView needed
- Compose handles dynamic/data-driven UI more naturally than SwiftUI — no `AnyView` type erasure, just call composables dynamically via `when(component.type)`
- Jetpack Compose is the standard for new Android apps in 2026
- The original `ItemAdapter.java` ViewType explosion problem (JSON stringification) is eliminated — Compose dispatches by component type function, not ViewHolder type integer

**QuickJS over Rhino (Performance Oracle + Framework Docs Research):**
- **Commit to QuickJS** for the expression evaluator on Android
- QuickJS: 380KB binary, ES2023 compliant, 35K GitHub stars, actively maintained
- Rhino: 1.5MB, ES5 only, slow startup, Mozilla has deprioritized
- Use [nickvdp/nickel](https://github.com/nickvdp/nickel) or [nickel](https://nickel-lang.org/) bindings — or the [nickel](https://nickel-lang.org/) project
- Alternative: use JSEP + AST walker in Kotlin (port from TypeScript) for expression evaluation, reserve QuickJS for `$script.*` only

**Dynamic Component Dispatch (replaces ViewHolder strategy):**
- With Compose, the original `ItemAdapter.java` ViewHolder explosion problem disappears entirely
- Instead of ViewHolder types, use `when(component.type)` to dispatch to the correct `@Composable` function
- Complex cells (e.g., horizontal scroll inside vertical list) use nested `LazyRow` inside `LazyColumn` items

**Kotlin Coroutines for Actions (Framework Docs Research):**
- Use `CoroutineScope(Dispatchers.Main + SupervisorJob())` for action execution
- Each action chain runs as a coroutine — `success` handler is `continuation`, `error` is `catch`
- `$timer` uses `delay()` (cancellable coroutine, not `Handler.postDelayed`)
- `$network.request` uses OkHttp's `suspend` extensions
- Cancellation propagates naturally: navigating away cancels the screen's coroutine scope

**$agent Bridge on Android (Security Review):**
- `WebView.addJavascriptInterface` exposes annotated methods to JS — use `@JavascriptInterface` sparingly
- Only expose a single `postMessage(String)` method, parse/validate on the Kotlin side
- Set `WebSettings.setJavaScriptEnabled(true)` only for `$agent` web containers, not `HtmlComponent`

---

### Phase 4: Jasonpedia Refresh (Weeks 13-17)

**Goal:** Update the example/test suite and turn it into a living specification.

#### 4.1 — Audit and Fix Examples

- [ ] Test every JSON file against Web, iOS, and Android renderers
- [ ] Fix broken API URLs (weather APIs, external services — e.g., `jasonbase.com` may be dead)
- [ ] Remove references to abandoned services
- [ ] Update asset URLs (images must be re-hosted under the new org's GitHub Pages)
- [ ] Resolve cross-platform font names: map iOS-specific fonts (`HelveticaNeue-CondensedBold`, `AvenirNext-Bold`) to generic families (`sans-serif`, `serif`, `monospace`) or platform equivalents

#### 4.2 — Expand Coverage

- [ ] Add examples for new platform capabilities (dark mode, dynamic type, accessibility)
- [ ] Add edge case examples (empty data, error states, large lists)
- [ ] Add integration test examples (multi-screen flows, deep linking)

#### 4.3 — Interactive Playground

- [ ] Build a web-based playground using the `@jasonette/web` package
- [ ] Live JSON editor on the left, rendered preview on the right
- [ ] Pre-loaded with all Jasonpedia examples
- [ ] Shareable URLs for JSON snippets
- [ ] Host at `playground.jasonette.com` or similar

**Deliverable:** Updated Jasonpedia with all examples verified across platforms, plus an interactive web playground.

---

### Phase 5: Ecosystem and Community (Weeks 17-21)

**Goal:** Make the project sustainable beyond a single maintainer.

#### 5.1 — Documentation Site

- [ ] Project website with getting started guide, API reference, tutorials
- [ ] Generated from the `$jason` schema spec
- [ ] Migration guide from original Jasonette
- [ ] Comparison with DivKit, Hyperview, and other SDUI frameworks

#### 5.2 — Developer Tools

- [ ] VS Code extension for `$jason` JSON (autocompletion, validation, preview)
- [ ] CLI tool: `jasonette validate app.json`, `jasonette serve app.json`
- [ ] JSON Schema published to SchemaStore for editor support

#### 5.3 — Governance

- [ ] Establish 3+ maintainers with merge access (bus factor > 1)
- [ ] CONTRIBUTING.md with clear guidelines
- [ ] RFC process for schema changes
- [ ] Regular release cadence (monthly patches, quarterly features)
- [ ] Open governance model (not dependent on any single person or company)

#### 5.4 — Community Building

- [ ] Announce revival on Hacker News, Reddit r/programming, relevant Discords
- [ ] Write "Jasonette is Back" blog post explaining the history and vision
- [ ] Showcase real apps built with the revived framework
- [ ] Accept community JSON components and actions as plugins

**Deliverable:** Documentation site, developer tools, and a sustainable community structure.

---

## Security Architecture

Jasonette apps execute JSON fetched from remote URLs, including template expressions that evaluate JavaScript. This is a significant attack surface that must be addressed from the start.

### Template Expression Sandboxing

| Platform | Engine | Sandbox Rules |
|---|---|---|
| Web | Restricted `Function()` or custom AST evaluator | No access to `window`, `document`, `fetch`, `XMLHttpRequest`. Only `$jason` context, `Math`, `JSON`, `String`, `Array`, `Object` builtins. |
| iOS | `JavaScriptCore` (JSContext) | No access to UIKit, Foundation, or any native APIs. Context contains only the `$jason` data object and safe builtins. |
| Android | `QuickJS` or `Rhino` | No access to Android APIs, `Runtime.exec()`, reflection, or file system. Context contains only the `$jason` data object and safe builtins. |

### Web Container Security

- WKWebView (iOS) and Android WebView must have **Content Security Policy** headers set
- The `$agent` bridge should only accept messages from the expected origin
- URL scheme restrictions: block `file://`, `javascript:`, and custom schemes unless explicitly configured
- Link interception must sanitize URLs before opening in external browser

### Network Security

- iOS: Require HTTPS by default via App Transport Security. Document how to add exceptions for development.
- Android: Use `android:networkSecurityConfig` to enforce HTTPS. Allow cleartext only for `localhost` in debug builds.
- Certificate pinning is opt-in via `jasonette.config.json` (not default — too fragile for most use cases)

### Credential Storage

- `$oauth` tokens stored in iOS Keychain / Android EncryptedSharedPreferences
- `$session` cookies stored in platform cookie jars (HTTPCookieStorage / OkHttp CookieJar)
- `$cache` data stored in plaintext (it's user data, not secrets). Document that `$cache` is not for sensitive data.

### Trust Model

A Jasonette app trusts the server that serves its JSON. If that server is compromised, the app renders attacker-controlled UI and executes attacker-controlled template expressions. This is inherent to the architecture (same as a web browser trusting the web server). Document this clearly so developers understand the security boundary.

### Research Insights: Security Deepening (18 Findings)

**Critical (Must Fix Before Any Release):**

1. **Web template engine MUST use AST-based evaluator** — `Function()` constructor is not sandboxable. Even with restrictions, `Function('return this')()` escapes any `with()` sandbox and accesses `window`. Use JSEP + AST walker (see Phase 0.5 Research Insights).

2. **`$agent.inject` is Remote Code Execution** — The original `$agent.inject` allows injecting arbitrary JavaScript into web containers. This lets a compromised JSON server execute arbitrary code in any WebView. Replace with a structured message-passing protocol only (`$agent.request`/`$agent.response`).

3. **SSRF protection for `$network.request`** — Without URL validation, a malicious JSON can make the user's device send requests to internal networks (`192.168.*`, `10.*`, `169.254.*`, `localhost`). Add an SSRF blocklist for private IP ranges and `file://` URLs.

4. **Prototype pollution prevention** — Template expressions that access `$jason.__proto__` or `$jason.constructor.prototype` can pollute the JavaScript prototype chain. The AST walker must block access to `__proto__`, `constructor`, and `prototype` properties.

**High (Should Fix for v1.0):**

5. **Expression complexity limits** — Malicious JSON can craft deeply nested expressions (`((((((a))))))` × 1000) to cause stack overflow or CPU exhaustion. Enforce: max AST depth 20, max 50 nodes per expression, 10ms evaluation timeout.

6. **URL scheme injection** — `$href` with `"view": "app"` calls `UIApplication.open()` / `startActivity(Intent)`. Validate URL schemes: block `javascript:`, `file:`, `data:` schemes. Allowlist: `http:`, `https:`, `mailto:`, `tel:`, `sms:`.

7. **OAuth PKCE mandatory** — Never store `client_secret` in the app binary. Use PKCE flow with `ASWebAuthenticationSession` (iOS) and Custom Tabs (Android). Remove `client_secret` from `jasonette.config.json`.

8. **iOS Privacy Manifest** — Required since Spring 2024. Must be present in the Xcode project or the app will be rejected. Declare: `NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`.

**Medium (Should Fix for v1.1):**

9. **Content Security Policy for web containers** — Set CSP headers on WKWebView/Android WebView to prevent XSS in `$agent` web containers.

10. **Mixin fetch validation** — The `@` mixin operator fetches arbitrary URLs. Apply the same SSRF blocklist as `$network.request`. Enforce maximum recursion depth (5) and total mixin size limit (1MB).

11. **JSON size limits** — No limit on fetched JSON size can cause OOM. Set default limit of 5MB for `$jason` JSON payloads, configurable in `jasonette.config.json`.

12. **Credential isolation** — `$cache` (plaintext) and `$oauth` (keychain) should use separate storage namespaces to prevent accidental token exposure.

---

## Alternative Approaches Considered

### 1. Patch the Existing Code

**Rejected.** The iOS code uses UIWebView (hard App Store blocker), targets iOS 8/9.3, is 100% Objective-C with 42 CocoaPods dependencies. The Android code uses dead jcenter, targets SDK 28, uses AGP 3.5.1. Patching every file is equivalent effort to rewriting, but slower because you must understand legacy patterns first.

### 2. Adopt DivKit and Abandon Jasonette

**Rejected.** DivKit solves a similar problem but has a different (more complex) JSON schema, requires Yandex's toolchain, and doesn't preserve Jasonette's simplicity. The `$jason` schema is elegant and well-documented through 100 examples.

### 3. Build on Top of React Native / Flutter

**Considered but deferred.** A React Native backend (like Hyperview does) could accelerate development, but adds a heavy runtime dependency. The original Jasonette vision was truly native with no bridge layer. This could be a Phase 6 option.

### 4. Join Forces with Jasonelle

**Possible but unlikely.** Jasonelle pivoted to "web app wrapper" with commercial licensing, which is a different product vision. If Jasonelle's maintainer is interested in collaboration, this door remains open.

---

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Insufficient contributors | High | High | Start with Web (smallest scope), ship something useful fast to attract contributors |
| Schema needs breaking changes | Medium | Medium | Version the schema (v2.0), provide migration tooling |
| Apple/Google platform changes | Low | Medium | Target recent-but-stable SDK versions (iOS 16, Android 26), not bleeding edge |
| DivKit captures the entire market | Low | Low | Jasonette's niche is simplicity; DivKit is enterprise-grade complexity |
| Single maintainer burnout | High | Critical | Governance model from day 1, require 3+ maintainers before v1.0 |
| Legal issues with name/brand | Low | Medium | The original MIT license allows forking; "Jasonette" isn't trademarked |
| Cannot reclaim GitHub org | Medium | Low | Work under a new org name (e.g., `jasonette-dev`); the code and brand value transfers via stars/SEO |
| Template engine scope creep | Medium | High | Phase 0.5 prototype with all Jasonpedia tests is the go/no-go gate; do not proceed without passing |
| Remote code execution via templates | High | Critical | Sandbox JS evaluation on all platforms from day 1 (see Security Architecture section) |

### Research Insights: Simplicity & Scope Reduction

**Phase Structure (Simplicity Review):**

The current 7-phase plan (0, 0.5, 1, 2, 3, 4, 5) could be reduced to 4 phases for v1.0:
- **Phase A: Spec + Template Engine** — merge Phase 0 + 0.5 + Gate Review
- **Phase B: Web Renderer** — Phase 1 (minus developer tools)
- **Phase C: iOS** — Phase 2
- **Phase D: Community Launch** — merge Phase 4 (Jasonpedia fix) + Phase 5 (docs/governance)

This reduces coordination overhead and decision points.

**Cut Android from v1.0 (Simplicity Review):**
- Shipping Web + iOS is sufficient to prove the concept and attract contributors
- Android can be v1.1 (contributed by the community or a second maintainer)
- This halves the native implementation effort for v1.0
- Counter-argument: Android has 70%+ global market share. Consider this a strategic tradeoff.

**Cut from v1.0 Scope (Simplicity Review):**
- `npx create-jasonette` scaffold — README example is sufficient
- Interactive playground (`playground.jasonette.com`) — defer to v1.1
- VS Code extension — JSON Schema on SchemaStore provides autocompletion for free
- Browser DevTools panel — use `$log` action and browser console
- CLI tool for validation — **disagree**: keep this per Agent-Native Review (but minimal: `validate` and `serve` only)

**"3+ maintainers before v1.0" is a Deadlock (Simplicity Review):**
- You can't attract maintainers without a shipped product
- Ship v1.0 with 1 committed maintainer + the product itself as the recruiting tool
- Change success metric to: "3+ active contributors (not necessarily with merge access) within 6 months"

---

## Success Metrics

1. **Web renderer passes 100% of Jasonpedia view examples** within Phase 1
2. **iOS and Android apps accepted by App Store / Google Play** within Phase 3
3. **3+ active maintainers with merge access** before any v1.0 release
4. **100+ GitHub stars on the new org** within 3 months (signals community interest)
5. **At least 1 real app shipped** using the revived framework within 6 months

---

## Agent-Native Design

Jasonette's JSON-driven architecture is naturally agent-friendly — JSON in, UI out. But without explicit agent paths, 13 of 15 capabilities (rendering, navigation, state, actions, etc.) are only accessible via human interaction with the running app.

**Core Principle:** Anything a user can do, an agent should be able to do. Anything a user can see, an agent should be able to see.

**CLI Tool (Move to Phase 1):**
```bash
# Validate JSON schema
jasonette validate app.json --format json

# Serve with live reload
jasonette serve app.json --port 3000

# Render to structured output (agent-consumable)
jasonette render app.json --output json

# Execute an action chain and return result
jasonette exec app.json --action '$network.request' --options '{"url":"..."}' --format json

# Lint template expressions for security issues
jasonette lint app.json --format json
```

**Structured Render Output:**
- `jasonette render` should output a JSON tree of the rendered component hierarchy
- Include computed styles, resolved template values, and action bindings
- This enables agents to inspect, test, and validate renders without a browser/simulator

**Action Execution Tracing:**
- Add a `--trace` flag to action execution that logs every action invocation, its inputs, outputs, and timing
- Output as JSON array for agent consumption
- Useful for debugging action chains and performance profiling

**Accessibility Tree Output:**
- `jasonette render --accessibility` outputs the accessibility tree (labels, roles, hints)
- Enables automated accessibility testing by agents

---

## Performance Architecture (Cross-Platform)

These performance requirements apply to all platform implementations:

**P0 — Must Have:**
1. **Singleton expression evaluator per app** — Create one JSEP parser / JSContext / QuickJS instance at app startup. Reuse across all expression evaluations. Never create per-parse-call.
2. **Expression compilation cache** — LRU cache (key: expression string, value: parsed AST). Most Jasonette apps reuse the same expressions across items/screens. Target: 1000-entry cache, ~100KB memory.
3. **Pre-evaluate `#each` before render** — Parse the `#each` body template once, then apply to each item. Do not re-parse the template string per array element.

**P1 — Should Have:**
4. **Parallel mixin fetch** — When a JSON document has multiple `@` mixin references, fetch them concurrently (not sequentially). Use `Promise.all` (web), `TaskGroup` (iOS), `coroutineScope` (Android).
5. **Eliminate `with` statements and prototype mutation** — The original `st.js` uses `with(this)` and mutates `Object.prototype`. Both destroy JS engine optimizations (V8 deoptimizes entire functions containing `with`). The JSEP + AST walker approach avoids this entirely.

**P2 — Nice to Have:**
6. **Virtual scrolling for large lists** — If a `sections/items` array has 100+ items, render only visible items + buffer. Use `UICollectionView` prefetching (iOS), Compose `LazyColumn` built-in recycling (Android), Intersection Observer (web).
7. **Mixin response caching** — Cache fetched mixin JSON with configurable TTL (default: 5 minutes). Invalidate on `$reload`.

---

## Effort Estimates

| Phase | Scope | Estimated Effort | Notes |
|---|---|---|---|
| Phase 0: Foundation | Schema spec, action catalogue, execution model, CI/CD, governance | 2 weeks | |
| Phase 0.5: Template Engine | JSEP + AST walker, conformance test suite, validate against Jasonpedia | **2-3 weeks** | Increased from 1 week per architecture review |
| Phase 1: Web + CLI | TypeScript rewrite, Tier 1 actions, SPA navigation, CLI (validate/serve/render) | 3-4 weeks | CLI added per agent-native review |
| Gate Review | Verify spec stability, template engine, web rendering | 1 week | |
| Phase 2: iOS (Tier 1) | Swift/UICollectionView+SwiftUI rewrite, all components + Tier 1 actions + $session | 8 weeks | Hybrid: UICollectionView + UIHostingConfiguration |
| Phase 3: Android (Tier 1) | Kotlin/Compose rewrite, all components + Tier 1 actions + $session | 8 weeks (parallel with iOS) | Jetpack Compose LazyColumn; consider deferring to v1.1 |
| Phase 4: Jasonpedia + Docs | Audit examples, fix URLs, docs site, CONTRIBUTING.md | 3 weeks | Merged Phase 4+5, cut playground |
| **Total to v1.0 (with Android)** | | **~17-19 weeks with iOS/Android in parallel** | |
| **Total to v1.0 (Web + iOS only)** | | **~12-14 weeks** | Per simplicity review |
| **Post-v1.0: Tier 2** | Media, geo, audio, agent, session, Android (if deferred) | +8 weeks | |
| **Post-v1.0: Tier 3** | OAuth (PKCE), WebSocket, push, script, vision | +6 weeks | |
| **Post-v1.0: Rust core** | Shared template engine in Rust via UniFFI (iOS/Android) + wasm (web) | +4-6 weeks | Eliminates 3 separate template engine implementations |

---

## References

### Internal

- `JASONETTE-iOS/app/Jasonette/` — 57 Objective-C source files, 3,901-line `Jason.m` core
- `JASONETTE-iOS/app/Podfile` — 42 CocoaPods dependencies targeting iOS 8.0
- `JASONETTE-Android/app/build.gradle` — compileSdk 28, AGP 3.5.1, jcenter()
- `Jasonette-Web/src/` — 13 JS files, 1,033 lines total
- `Jasonpedia/` — 100 JSON example files across 5 categories

### External

- [DivKit — Yandex Server-Driven UI](https://github.com/divkit/divkit) — closest modern alternative
- [Hyperview — Server-driven mobile apps](https://hyperview.org/) — XML-based SDUI on React Native
- [Apple: Upcoming SDK Requirements](https://developer.apple.com/news/upcoming-requirements/) — Xcode 16 / iOS 18 SDK required
- [Google Play: Target API Requirements](https://developer.android.com/google/play/requirements/target-sdk) — API 35 required Aug 2025
- [CocoaPods Sunset (Dec 2026)](https://blog.cocoapods.org/) — read-only mode
- [jcenter Shutdown (Aug 2024)](https://jfrog.com/blog/jcenter-sunset/) — fully offline
- [Jasonette's Future — Issue #23](https://github.com/Jasonette/Jasonette/issues/23) — community discussion after Ethan's disappearance
- [Jasonelle Organization](https://github.com/jasonelle/jasonelle) — community fork (71 stars)

### Added by UI Framework Brainstorm

- [Brainstorm: SwiftUI & Compose](../brainstorms/2026-02-26-swiftui-compose-ui-framework-brainstorm.md) — decision document
- [UIHostingConfiguration (Apple Docs)](https://developer.apple.com/documentation/swiftui/uihostingconfiguration) — iOS 16+ SwiftUI in UICollectionView
- [HEMA SDUI Migration (Q42 Engineering)](https://engineering.q42.nl/swiftui-hema-app/) — 58 components in production
- [ReactiveCollectionsKit (Duolingo)](https://github.com/jessesquires/ReactiveCollectionsKit) — production UICollectionView wrapper
- [Backend-Driven SwiftUI (Jacob Bartlett)](https://blog.jacobstechtavern.com/p/backend-driven-swiftui) — SDUI patterns
- [List or LazyVStack (Fatbobman)](https://fatbobman.com/en/posts/list-or-lazyvstack/) — recycling analysis
- [Compose Multiplatform 1.8.0 Stable (JetBrains)](https://blog.jetbrains.com/kotlin/2025/05/compose-multiplatform-1-8-0-released/) — CMP for iOS rejected

### Added by Deepen-Plan Research

- [JSEP — JavaScript Expression Parser](https://github.com/EricSmekworthy/jsep) — recommended expression evaluator (3KB, zero deps)
- [QuickJS — Lightweight JS Engine](https://bellard.org/quickjs/) — recommended for Android JS execution (380KB, ES2023)
- [Apple Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) — required since Spring 2024
- [OAuth 2.0 PKCE](https://datatracker.ietf.org/doc/html/rfc7636) — mandatory for native app OAuth
- [Vite Library Mode](https://vitejs.dev/guide/build.html#library-mode) — recommended build tooling for npm package
- [Vitest](https://vitest.dev/) — recommended test framework for TypeScript
