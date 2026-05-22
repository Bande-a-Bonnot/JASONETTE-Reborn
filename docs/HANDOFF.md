# Agent Handoff Document

Last updated: 2026-05-21

**Update this file before context compaction and at the end of significant sessions.**

## Current State

### Test Suite

- iOS: 456 tests, 0 failures (verified 2026-05-21 after legacy inline/footer-shell tab selected-state + accessibility fallback labels; previous inline footer-tab self-target no-op fix brought suite to 454)
- Android CI: `pull_request` Android job ran/passed on PR #21, non-Android-change PR #22, and follow-up PR #23; Kotlin JSON primitive accessor compile failures fixed by squash `92e65dd`; oversized plain-integer JSON parsing aligned between Android test helper and production renderer in `c3f4f8f`
- Run iOS: `cd JASONETTE-iOS/JasonetteApp && swift test`
- Build iOS: `swift build` (<1s)

### Version

- `MARKETING_VERSION: "2.0.0"` / `CURRENT_PROJECT_VERSION: "1"` (managed by Xcode Cloud)
- Team ID: `PKPPLFK854`

### What Ships

- iOS app on TestFlight via Xcode Cloud
- Demo JSON hosted at `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json`

---

## What's Working (iOS Renderer)

### Components (11)

label, image, button, textfield, textarea, slider, switch, space, map (stub — no pins/region), vertical, horizontal

### Actions (12 working / 4 stubs)

| Working | Stubs (no-op) |
|---------|---------------|
| `$set`, `$cache.set`, `$cache.reset`, `$render`, `$reload`, `$href`, `$back`, `$close`, `$network.request`, `$util.alert`, `$timer.start`, `$timer.stop` | `$get`, `$cache.get`, `$util.toast`, `$util.banner` |

### Rendering Pipeline

```
JSON → JasonDocument (Codable) → TemplateEngine → JasonetteViewModel → JasonetteView → ComponentView
```

- **Templates**: Dynamic named templates via `$render` with `options.template`. Default "body".
- **Layers**: ZStack overlays above ScrollView. Positioned via top/left/bottom/right + alignment + padding.
- **Body background**: Color string parsed via `Color(css:)`, applied with `.ignoresSafeArea()`.
- **Footer**: tabs (HStack) or input (dedicated `FooterInputView`), mutually exclusive.
- **Style chain**: applyFont → applyColors → applySpacing → applyBorder → applySize → applyOpacity → applyAlignment

---

## What's Broken / Not Implemented

See `docs/plans/2026-03-28-fix-ios-components-actions-audit-plan.md` for the full audit. Summary:

### Phase B — Missing Actions

`$util.toast/banner`, `$snapshot`, `$util.share`, `$audio.play`, `$geo.get`, `$media.camera`

### Phase C — Component Fixes

Map pins/region, HTML component (`WKWebView`), animated GIF, keyboard dismiss on text inputs. Secure textfield renderer path is implemented with `SecureField`; typed-secret accessibility confirmation is still pending because simulator automation timed out.

### Phase D — Data & Navigation

Relative URL resolution now uses the final loaded document URL across shell-mounted footer tabs and the main renderer/action paths. `DocumentLoader.loadWithMetadata` captures the final URL; `TabDescriptor.init(from:baseURL:)`, `JasonetteViewModel.handleHref`, `$network.request`, body image/button components, footer input buttons, and the legacy `FooterTabItemView` icon path resolve authored relative references via `JasonURL.resolve` before navigation/network scheme allowlist checks. `$network.request` response shape preservation is fixed on `main` (PR #17): object, array, string, number, and null JSON response bodies are stored under `$response`.

Tab navigation rewrite is on `main` (PR #20, plan at `docs/plans/tab-navigation-overhaul/plan.md`). Shell owns selection; each tab is an opaque `JasonetteNavigationView` mounted lazily on first selection and kept alive after. Action-only footer tabs dispatch through `TabActionRegistry` + environment registration; `$href` action tabs that target an existing document tab are intercepted by the shell and switch selection instead of pushing onto the active tab's nav stack. See solution doc `architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md`.

### Open Todos

P1:
- none currently tracked as open

P2:
- `todos/040` — secure textfield renders/exposes plain text (code fix + structural tests added 2026-05-20; fixture load screenshot captured, but typed-secret simulator accessibility confirmation still pending because `agent-device` runner timed out during asset-catalog processing)
- `todos/041` — HTML component renders `[Unknown: html]`

P3:
- `todos/015` — sectionView code duplication (defer until 3rd section type)
- `todos/016` — solution doc version inconsistency
- `todos/017` — plan doc hygiene
- `todos/018` — ButtonComponent imageURL consistency
- `todos/020` — same-axis layer constraints
- `todos/021` — rgba/hex8 background color tests
- `todos/022` — footer button image failure placeholder
- `todos/027` — action-tab canonical-key content hash
- `todos/029` — onChange iOS 17 modernization
- `todos/033` — Android JSON decimal/exponent precision policy (Gemini PR #23 follow-up; plain integers fixed, decimal/exponent still use `Double` by current contract)
- `todos/036` — non-tab image URL scheme policy (PR #24 follow-up)
- `todos/037` — ViewModel documentURL redirect coverage
- `todos/038` — footer-tab app-scheme baseURL coverage
- `todos/043` — debug launch URL override for simulator QA
- `todos/044` — investigate device-specific simulator build hang during asset catalog processing

Completed this session:
- `todos/042` implementation — legacy inline footer tabs now maintain local selected index, show a selected capsule indicator for icon-only tabs, and expose non-empty accessibility labels with authored text first and per-position fallback labels for icon-only tabs; shell-mounted footer tabs also expose fallback labels and selected accessibility values. Added URLResolutionTests for label fallback behavior. User confirmed tabs are good in TestFlight once the fix was included.
- Build 52 follow-up — TestFlight still pushed duplicate views when tapping legacy inline `footer.tabs` items whose target is the current document (e.g. pushed Jasonpedia `core/href/tabs.json`). Root shell tabs and action-href tab switching were already fixed, but pushed/single-stack legacy footer tabs still used the old synthesized-href path. `FooterTabItemView` now no-ops current-document targets after relative resolution/standardization, preserving different-target navigation; added URLResolutionTests coverage. User later confirmed the fixed tabs are good in TestFlight.
- `todos/040` implementation — `JasonStyle.secure` now decodes/merges and `TextFieldComponent` routes `style.secure` truthy values plus legacy `type: "secure"` through SwiftUI `SecureField` while preserving `StateManager` binding and initial-value behavior; added ComponentDispatch, StyleModifier, and Jasonpedia textfield fixture tests. Simulator direct-fixture screenshot confirms the textfield page loads, but typed-secret accessibility confirmation remains pending because `agent-device` runner setup timed out during asset-catalog processing. Also wrote `~/jasonette-ios-simulator-qa-findings-2026-05-18.md` summarizing the QA methodology, tool commands, prompts, and findings.
- `todos/039` implementation — `#each` now merges object item fields into the per-item template context so original Jasonette direct identifiers like `{{title}}`/`{{url}}` render while preserving `{{$jason}}`, `this`, `$index`, and `$root`; added TemplateEngine regression coverage for object-form `items`, nested components, non-array empty output, plus ViewModel tests against `Jasonpedia/template/index.json` and `Jasonpedia/action/network/index.json`. Simulator direct-fixture screenshots confirm the Template and `$network` blank-list regressions are gone; see `docs/qa/2026-05-20-ios-simulator-post-fix-qa.md`.
- `todos/025` — footer tab-bar style/icon parity: shell tab cells now consume inherited/inline tab style, show selected tint + indicator, render `system://` SF Symbols without `AsyncImage`, and keep network-image failure placeholders.
- `todos/026` — action-tab dispatch: action-only footer tabs now construct/render, taps forward to the selected tab's active `JasonetteViewModel` action dispatcher, and `$href` action tabs targeting existing tabs switch instead of push; no-selectable action-only footers remain single mode.
- iOS simulator QA notes added at `docs/qa/2026-05-18-ios-simulator-complete-qa.md`; process notes added at `docs/qa/README.md`; compounded learnings added at `docs/solutions/best-practices/agent-device-ios-simulator-exploratory-qa.md`. `agent-device` 0.14.9 works for Simulator driving (`npx --yes agent-device@latest ...`). Key findings are tracked as todos/039-044.

Nice-to-have (P3):
- `todos/031` — investigate ZStack nav-title collision (gemini r5/6/7/8 concern)
- `todos/032` — codebase-wide URL normalization utility (supersedes `.standardized` per-site)

---

## Key Patterns (Read Before Coding)

### Three-Place Rule

New `JasonStyle` properties must go in: (1) struct field, (2) `CodingKeys`, (3) `merging()`. Then verify the rendering code actually reads it.

### ifLet for Optional Modifiers

Never pass nil to SwiftUI modifiers — nil actively overrides parent values. Use:
```swift
view.ifLet(style.opacity?.cgFloat) { $0.opacity($1) }
```

### strokeBorder not stroke

`.stroke()` clips half the border outside bounds. `.strokeBorder()` draws inside.

### Structural Elements Get Dedicated Views

Footer and header are NOT routed through `ComponentView`. They have fixed semantics and their own views (`FooterInputView`).

### Layers are ZStack Overlays

Not inside the ScrollView. Positioned via alignment + padding from the aligned edge. `Color.clear.allowsHitTesting(false)` as spacer.

### Process Mode: Review-Only vs Foundry Red/Green

Do not call normal CodeRabbit/Gemini/Codex review "adversarial". Foundry red/green means red writes tests from Definition of Done, green implements from How, and the orchestrator sends only test-name PASS/FAIL outcomes while preserving the information barrier. See `workflow-issues/foundry-adversarial-red-green-information-barrier.md`.

---

## Solution Docs (45 total, category dirs plus legacy root docs)

Search `docs/solutions/` by YAML frontmatter: `module`, `tags`, `problem_type`, `category`.

Key docs for this codebase:
- `ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md` — the 4 renderer foundation fixes
- `build-errors/swiftui-modifier-gotchas.md` — nil-override trap, strokeBorder, all optional modifiers
- `build-errors/tuist-extendingdefault-hardcoded-version.md` — Tuist Info.plist versioning
- `best-practices/parallel-pr-swarm-with-git-worktrees.md` — worktree swarm pattern
- `best-practices/automated-review-comment-handling.md` — CodeRabbit/Gemini/Copilot handling; rate-limit comments are not reviews
- `best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md` — CodeRabbit + Codex/pi xhigh second-pass review (review-only, not Foundry red/green)
- `best-practices/url-identity-semantics-belong-at-the-url-layer.md` — URL normalization belongs at the URL layer, not at each call site
- `best-practices/github-review-decision-stickiness-dismiss-stale-reviews.md` — `reviewDecision` only transitions on formal reviews; dismiss stale CHANGES_REQUESTED via API
- `best-practices/loop-mode-pr-babysit-discipline.md` — Monitor + ScheduleWakeup discipline for long-running PR-babysit sessions
- `best-practices/agent-device-ios-simulator-exploratory-qa.md` — `agent-device`/XCTest-runner workflow for agent-driven Simulator QA plus session learnings
- `best-practices/deferred-feedback-todo-four-part-structure.md` — Context + Ask + Why-not-now + Locked-in tests
- `workflow-issues/foundry-adversarial-red-green-information-barrier.md` — Foundry red/green = red tests from DoD, green implementation from How, PASS/FAIL-only mediation
- `documentation-gaps/todo-completion-notes-ci-evidence.md` — handoff/todo CI claims need precise PR/run/event evidence
- `integration-issues/xcode-cloud-accent-character-team-name-crash.md` — accent in account name
- `architecture-patterns/reviving-a-decade-old-cross-platform-project.md` — 19 learnings from the revival
- `architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md` — shell owns selection, each tab owns its own nav; lazy mount + SceneStorage canonical-key restore
- `runtime-errors/anycodable-nsjsonserialization-crash.md` — always `.unwrapped` before JSONSerialization
- `build-errors/kotlinx-json-numeric-accessors-android-test-compile.md` — Android Kotlin JSON accessor imports + aligned test/production plain-integer parsing

---

## File Map

```
JASONETTE-iOS/JasonetteApp/
├── Sources/Jasonette/
│   ├── Core/           — JasonDocument.swift, ActionDispatcher.swift, StateManager.swift, AnyCodable.swift, DocumentLoader.swift
│   ├── Template/       — TemplateEngine.swift, ExpressionParser.swift, ExpressionEvaluator.swift
│   ├── Rendering/      — JasonetteView.swift, JasonetteViewModel.swift, JasonetteNavigationView.swift
│   │   └── Navigation/ — JasonetteRootView, JasonetteTabShell, JasonetteNavigationCoordinator,
│   │                     TabShellState, TabEntry/TabDescriptor/TabID, FooterTabBar, UUIDv7,
│   │                     JasonetteEnvironment (env keys: isInsideTabShell, switchTab)
│   └── Components/     — ComponentRegistry.swift, JasonStyleModifier.swift, LayoutView.swift, + individual components
├── Tests/JasonetteTests/  — 17 test files
├── Project.swift          — Tuist manifest
└── Package.swift          — SPM manifest
```

---

## Git & CI

- `export SSH_AUTH_SOCK=~/.ssh/agent.sock` before push/pull/fetch
- Android CI: `android` check currently green after PR #21 fixed Kotlin test unresolved references and PR #23 aligned oversized plain-integer parsing in test + production converters
- iOS CI: `ios` + `lint` + `changes` checks must pass
- CodeRabbit reviews PRs automatically; rate-limits on 4+ simultaneous PRs
- Xcode Cloud handles archive → TestFlight
