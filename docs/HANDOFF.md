# Agent Handoff Document

Last updated: 2026-04-26

**Update this file before context compaction and at the end of significant sessions.**

## Current State

### Test Suite

- iOS: 386 tests, 0 failures (verified 2026-04-23; tab navigation rewrite merged to `main` via PR #20 squash `11b9fca`)
- Android CI: green on PR #21 / `main` (2026-04-26); Kotlin JSON primitive accessor compile failures fixed by squash `92e65dd`
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

Map pins/region, secure textfield (`SecureField`), HTML component (`WKWebView`), animated GIF, keyboard dismiss on text inputs

### Phase D — Data & Navigation

Relative URL resolution for sub-demo href/footer tabs remains open. `$network.request` response shape preservation is fixed on `main` (PR #17): object, array, string, number, and null JSON response bodies are stored under `$response`.

Tab navigation rewrite is on `main` (PR #20, plan at `docs/plans/tab-navigation-overhaul/plan.md`). Shell owns selection; each tab is an opaque `JasonetteNavigationView` mounted lazily on first selection and kept alive after. See solution doc `architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md`.

### Open Todos

P2:
- `todos/025` — footer tab-bar style/icon parity
- `todos/026` — action-tab dispatch
- `todos/030` — relative URL resolution in footer tabs

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

---

## Solution Docs (41 total, 11 categories)

Search `docs/solutions/` by YAML frontmatter: `module`, `tags`, `problem_type`, `category`.

Key docs for this codebase:
- `ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md` — the 4 renderer foundation fixes
- `build-errors/swiftui-modifier-gotchas.md` — nil-override trap, strokeBorder, all optional modifiers
- `build-errors/tuist-extendingdefault-hardcoded-version.md` — Tuist Info.plist versioning
- `best-practices/parallel-pr-swarm-with-git-worktrees.md` — worktree swarm pattern
- `best-practices/automated-review-comment-handling.md` — CodeRabbit/Gemini/Copilot handling
- `best-practices/url-identity-semantics-belong-at-the-url-layer.md` — URL normalization belongs at the URL layer, not at each call site
- `best-practices/github-review-decision-stickiness-dismiss-stale-reviews.md` — `reviewDecision` only transitions on formal reviews; dismiss stale CHANGES_REQUESTED via API
- `best-practices/loop-mode-pr-babysit-discipline.md` — Monitor + ScheduleWakeup discipline for long-running PR-babysit sessions
- `best-practices/deferred-feedback-todo-four-part-structure.md` — Context + Ask + Why-not-now + Locked-in tests
- `integration-issues/xcode-cloud-accent-character-team-name-crash.md` — accent in account name
- `architecture-patterns/reviving-a-decade-old-cross-platform-project.md` — 19 learnings from the revival
- `architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md` — shell owns selection, each tab owns its own nav; lazy mount + SceneStorage canonical-key restore
- `runtime-errors/anycodable-nsjsonserialization-crash.md` — always `.unwrapped` before JSONSerialization

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
- Android CI: `android` check currently green after PR #21 fixed Kotlin test unresolved references
- iOS CI: `ios` + `lint` + `changes` checks must pass
- CodeRabbit reviews PRs automatically; rate-limits on 4+ simultaneous PRs
- Xcode Cloud handles archive → TestFlight
