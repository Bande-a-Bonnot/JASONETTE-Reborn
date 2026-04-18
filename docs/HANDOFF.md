# Agent Handoff Document

Last updated: 2026-03-31

**Update this file before context compaction and at the end of significant sessions.**

## Current State

### Test Suite

- 335 tests, 0 failures
- Run: `cd JASONETTE-iOS/JasonetteApp && swift test`
- Build: `swift build` (<1s)

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

`$network.request` drops array responses, tabs render `[Unknown: nil]`, relative URL resolution for sub-demo href

### Open P3 Todos (8)

```
todos/015 — sectionView code duplication (defer until 3rd section type)
todos/016 — solution doc version inconsistency
todos/017 — plan doc hygiene
todos/018 — ButtonComponent imageURL consistency
todos/019 — extract shared resolveLayerStyle helper
todos/020 — same-axis layer constraints (left+right, top+bottom)
todos/021 — add rgba/hex8 background color tests
todos/022 — footer button image failure placeholder
```

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

## Solution Docs (27 total, 11 categories)

Search `docs/solutions/` by YAML frontmatter: `module`, `tags`, `problem_type`, `category`.

Key docs for this codebase:
- `ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md` — the 4 renderer foundation fixes
- `build-errors/swiftui-modifier-gotchas.md` — nil-override trap, strokeBorder, all optional modifiers
- `build-errors/tuist-extendingdefault-hardcoded-version.md` — Tuist Info.plist versioning
- `best-practices/parallel-pr-swarm-with-git-worktrees.md` — worktree swarm pattern
- `best-practices/automated-review-comment-handling.md` — CodeRabbit/Gemini/Copilot handling
- `integration-issues/xcode-cloud-accent-character-team-name-crash.md` — accent in account name
- `architecture-patterns/reviving-a-decade-old-cross-platform-project.md` — 19 learnings from the revival
- `runtime-errors/anycodable-nsjsonserialization-crash.md` — always `.unwrapped` before JSONSerialization

---

## File Map

```
JASONETTE-iOS/JasonetteApp/
├── Sources/Jasonette/
│   ├── Core/           — JasonDocument.swift, ActionDispatcher.swift, StateManager.swift, AnyCodable.swift, DocumentLoader.swift
│   ├── Template/       — TemplateEngine.swift, ExpressionParser.swift, ExpressionEvaluator.swift
│   ├── Rendering/      — JasonetteView.swift, JasonetteViewModel.swift, JasonetteNavigationView.swift
│   └── Components/     — ComponentRegistry.swift, JasonStyleModifier.swift, LayoutView.swift, + individual components
├── Tests/JasonetteTests/  — 17 test files
├── Project.swift          — Tuist manifest
└── Package.swift          — SPM manifest
```

---

## Git & CI

- `export SSH_AUTH_SOCK=~/.ssh/agent.sock` before push/pull/fetch
- Android CI fails on all PRs (pre-existing Kotlin test errors, unrelated to iOS work)
- iOS CI: `ios` + `lint` + `changes` checks must pass
- CodeRabbit reviews PRs automatically; rate-limits on 4+ simultaneous PRs
- Xcode Cloud handles archive → TestFlight
