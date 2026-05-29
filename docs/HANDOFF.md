# Agent Handoff Document

Last updated: 2026-05-28

**Update this file before context compaction and at the end of significant sessions.**

## Current State

### Test Suite

- iOS: 502 tests, 0 failures (verified 2026-05-29 after URL canonicalization; `swift build` succeeded); device-specific iPhone 17 Pro simulator `xcodebuild` verified 2026-05-29 after `tuist generate` and tab chrome QA fixture work
- Android CI: `pull_request` Android job ran/passed on PR #21, non-Android-change PR #22, and follow-up PR #23; Kotlin JSON primitive accessor compile failures fixed by squash `92e65dd`; oversized plain-integer JSON parsing aligned between Android test helper and production renderer in `c3f4f8f`; decimal/exponent policy is now explicitly documented as `Double` and centralized in Android `JsonValueConverter` (local Gradle verification blocked by missing Java runtime on 2026-05-26; limitation and CI fallback documented in `JASONETTE-Android/JasonetteApp/README.md`)
- Run iOS: `cd JASONETTE-iOS/JasonetteApp && swift test`
- Build iOS: `swift build` (<1s)

### Version

- `MARKETING_VERSION: "2.0.0"` / `CURRENT_PROJECT_VERSION: "1"` (managed by Xcode Cloud)
- Team ID: `PKPPLFK854`
- Active Swift/Tuist app floors: iOS 26.0, macOS 14.0, tvOS 17.0, visionOS 1.0

### What Ships

- iOS app on TestFlight via Xcode Cloud
- Demo JSON hosted at `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json`

---

## What's Working (iOS Renderer)

### Components (12)

label, image, button, textfield, textarea, slider, switch, space, html (`WKWebView`), map (`MapKit` region + pins), vertical, horizontal

### Actions (12 working / 4 stubs)

| Working | Stubs (no-op) |
|---------|---------------|
| `$set`, `$cache.set`, `$cache.reset`, `$render`, `$reload`, `$href`, `$back`, `$close`, `$network.request`, `$util.alert`, `$timer.start`, `$timer.stop` | `$get`, `$cache.get`, `$util.toast`, `$util.banner` |

### Rendering Pipeline

```
JSON → JasonDocument (Codable) → TemplateEngine → JasonetteViewModel → JasonetteView → ComponentView
```

- **Templates**: Dynamic named templates via `$render` with `options.template`. Default "body".
- **Layers**: ZStack overlays above ScrollView. Positioned via top/left/bottom/right + alignment + padding; `left`+`right` and `top`+`bottom` stretch between same-axis insets.
- **Body background**: Color string parsed via `Color(css:)`, applied with `.ignoresSafeArea()`.
- **Footer**: tabs (HStack) or input (dedicated `FooterInputView`), mutually exclusive.
- **Style chain**: applyFont → applyColors → applySpacing → applyBorder → applySize → applyOpacity → applyAlignment

---

## What's Broken / Not Implemented

See `docs/plans/2026-03-28-fix-ios-components-actions-audit-plan.md` for the full audit. Summary:

### Phase B — Missing Actions

`$util.toast/banner`, `$snapshot`, `$util.share`, `$audio.play`, `$geo.get`, `$media.camera`

### Phase C — Component Fixes

HTML component renderer path is implemented with `WKWebView` and simulator-confirmed on `Jasonpedia/view/component/html/index.json`. Secure textfield renderer path is implemented with `SecureField` and user-confirmed correct in TestFlight/simulator. Map component renderer path is implemented with MapKit and simulator-confirmed on the Jasonpedia map fixture plus pin-focused QA fixture. Animated GIF image URLs now route to a UIKit-backed `UIImageView` renderer on iOS while static images stay on `AsyncImage`; keyboard dismissal now covers textfield submit/done, secure textfield submit/done, textarea keyboard toolbar done, footer input submit/done, interactive scroll dismiss, and outside-tap responder-chain dismissal. Debug iOS builds now support direct entry URL overrides via `-JasonetteEntryURL` / `JASONETTE_ENTRY_URL`, with local tab/action-tab QA fixtures documented in `docs/qa/README.md`. GIF + keyboard direct fixture visual QA remains best-effort from before the override; see `docs/qa/2026-05-25-ios-gif-keyboard-best-effort-qa.md`.

### Phase D — Data & Navigation

Relative URL resolution now uses the final loaded document URL across shell-mounted footer tabs and the main renderer/action paths. `DocumentLoader.loadWithMetadata` captures the final URL; `TabDescriptor.init(from:baseURL:)`, `JasonetteViewModel.handleHref`, `$network.request`, body image/button components, footer input buttons, and the legacy `FooterTabItemView` icon path resolve authored relative references via `JasonURL.resolve` before navigation/network scheme allowlist checks. `$network.request` response shape preservation is fixed on `main` (PR #17): object, array, string, number, and null JSON response bodies are stored under `$response`.

Tab navigation rewrite is on `main` (PR #20, plan at `docs/plans/tab-navigation-overhaul/plan.md`). Shell owns selection; each tab is an opaque `JasonetteNavigationView` mounted lazily on first selection and kept alive after. Action-only footer tabs dispatch through `TabActionRegistry` + environment registration; `$href` action tabs that target an existing document tab are intercepted by the shell and switch selection instead of pushing onto the active tab's nav stack. See solution doc `architecture-patterns/swiftui-tab-shell-opaque-scope-navigation.md`.

### Open Todos

P1:
- none currently tracked as open

P2:
- none currently tracked as open

P3:
- none currently tracked as open

Completed this session:
- `todos/032` — added shared `URL.jasonetteCanonical` URL identity semantics (lowercased scheme/host, standardized path segments, trailing slash removal, default HTTP/HTTPS port dropping, sorted query items) and migrated equality-style navigation comparisons to it: tab canonical keys, switch-to-tab matching, bootstrap tab selection/preload hand-off, and legacy inline footer current-document no-op detection. Updated the old trailing-slash guardrail to assert collapse and added URL canonicalization/current-document coverage. Verification: `swift test --filter URLResolutionTests` (24 tests); `swift test --filter TabNavigationCoordinatorTests` (73 tests); full `swift test` — 502 tests, 0 failures; `swift build`.
- `todos/031` — hardened tab navigation chrome propagation by rendering the selected document tab last in `JasonetteTabShell`'s ZStack without mutating authored tab-bar order. Added `TabContentStackOrder` tests, local `chrome-*` simulator fixtures, and `docs/qa/2026-05-29-ios-tab-chrome-zstack-qa.md`; agent-device QA confirmed Home/Detail/Third titles and toolbar buttons remain visually correct after tab switches and a pushed child page. Verification: `jq empty docs/qa/fixtures/ios-simulator-tabs/chrome-*.json`; `swift test --filter TabNavigationCoordinatorTests` (73 tests); full `swift test` — 498 tests, 0 failures; `swift build`; `mise exec -- tuist generate --no-open`; device-specific iPhone 17 Pro simulator `xcodebuild` build; `agent-device` QA screenshots.
- `todos/015` — removed `sectionView` horizontal/vertical item-rendering duplication by extracting shared `sectionItemsView`/`sectionComponentView` helpers and a section padding modifier while preserving header, vertical-item, and horizontal-item padding semantics. Verification: full `swift test` — 496 tests, 0 failures; `swift build`.
- `todos/044` — investigated the prior device-specific iPhone 17 Pro simulator build hang. Regenerated the local Tuist project (`mise exec -- tuist generate --no-open`), added the missing `AccentColor.colorset` referenced by generated asset catalog settings, and verified both direct device-specific and generic simulator `xcodebuild` commands succeed without clearing app-icon/accent-color settings; install/launch also succeeded. Updated `docs/qa/README.md`, added `docs/qa/2026-05-28-ios-device-specific-build-qa.md`, and marked the todo complete.
- `todos/029` — raised active Swift/Tuist app floors to iOS 26.0, macOS 14.0, and tvOS 17.0 (visionOS remains 1.0); updated `JasonetteTabShell` to the modern two-parameter `onChange(of:)` closure; refreshed current README/contributing docs from iOS 16+ to iOS 26+. Verification: `swift package dump-package`; `rg` found no legacy single-parameter `onChange` or active iOS 16 target references; `swift test --filter TabNavigationCoordinatorTests` (71 tests); full `swift test` (496 tests); `swift build`; `npm run lint:md`.
- `todos/048` — documented Android Java 17 local verification requirements and the current no-Java local-agent limitation in `JASONETTE-Android/JasonetteApp/README.md`; recorded CI run/job evidence where the `android` job provisioned Java 17 and ran `./gradlew assembleDebug` plus `./gradlew test` successfully for the JSON conversion changes. Marked the todo complete.
- `todos/017` — updated `docs/plans/2026-03-19-fix-render-multiple-templates-plan.md` with `status: completed`, a completion date, and an accurate PR #12 completion summary replacing the confusing same-day deepening note. Marked the todo complete.
- `todos/016` — clarified `docs/solutions/integration-issues/xcode-cloud-accent-character-team-name-crash.md` so the `MARKETING_VERSION: "0.1.0"` Tuist setting and generated `CFBundleShortVersionString=1.0` Info.plist hardcoding are explicitly distinguished. Marked the todo complete.
- `todos/033` — centralized Android JSON conversion in `JsonValueConverter`, documented the decimal/exponent policy as intentionally `Double` for now, and updated both production `JasonetteViewModel` and `CrossPlatformTest` to use the same converter. Added `JsonValueConverterTest` coverage for `Int`→`Long`→exact `String` plain integers, high-precision decimals as `Double`, exponent values as `Double`, and `Long` round-tripping. Added solution doc `docs/solutions/build-errors/android-json-decimal-exponent-number-policy.md`. Local Gradle verification was attempted but blocked because no Java runtime is installed (`Unable to locate a Java Runtime`); `npm run lint:md` passed.
- `todos/020` — added `LayerPositioning` to derive layer insets, same-axis stretch flags, and alignment from `JasonStyle`, then updated `JasonetteView` layer rendering to stretch horizontally for `left`+`right` and vertically for `top`+`bottom` while preserving single-edge natural-size positioning. Added `LayerPositioningTests` for both stretch axes, single-edge no-stretch, and unpositioned no-stretch. Verification: `swift test --filter LayerPositioningTests`; full `swift test` — 496 tests, 0 failures; `swift build`; `npm run lint:md` — 0 errors.
- `todos/027` — added `JasonAction.stableHash` using sorted-key JSON encoding plus SHA-256 via CryptoKit, and changed `.action` tab canonical keys from `ObjectIdentifier(action)` to the content hash. Added TabNavigationCoordinator tests proving stable keys across independent decodes, different content changes keys, nested `success`/`error` branches participate, and duplicate action-only tabs dedupe during bootstrap. Action-only tabs remain intentionally non-selectable, so SceneStorage selected-tab restore remains document-tab-only. Verification: `swift test --filter TabNavigationCoordinatorTests`; full `swift test` — 492 tests, 0 failures; `swift build`.
- `todos/043` — added `JasonetteLaunchConfiguration` and updated the iOS app entrypoint so Debug builds can override the root document URL via `-JasonetteEntryURL`, `-JasonetteEntryURL=...`, or `JASONETTE_ENTRY_URL`; Release/TestFlight behavior remains the production Jasonpedia demo URL. Added `LaunchConfigurationTests`, local tabs/action-tabs simulator fixtures under `docs/qa/fixtures/ios-simulator-tabs/`, and exact `simctl`/`agent-device` usage in `docs/qa/README.md`. Verification: `jq empty docs/qa/fixtures/ios-simulator-tabs/*.json`; `swift test --filter LaunchConfigurationTests`; full `swift test` — 488 tests, 0 failures; `swift build`.
- `todos/047` — added shared iOS keyboard dismissal helpers: textfields and secure fields use Done/submit dismissal plus keyboard toolbar, textareas get a keyboard Done toolbar, footer input gets Done/submit dismissal, ScrollView uses interactive keyboard dismissal, and the document surface dismisses via responder-chain outside taps. Secure textfield routing and footer input binding remain unchanged. Full Swift suite: 483 tests, 0 failures; iOS simulator build succeeded (2026-05-25). Best-effort QA documented at `docs/qa/2026-05-25-ios-gif-keyboard-best-effort-qa.md`.
- `todos/046` — added `AnimatedGIFImage`, an iOS-only UIKit/ImageIO-backed `UIImageView` wrapper for `.gif` image URLs, while preserving static images on the existing `AsyncImage` path. Relative GIF URLs resolve against `documentURL` with existing http/https image policy. Added URLResolutionTests for GIF detection, query-string handling, relative GIF path selection, and static image path retention. Full Swift suite: 483 tests, 0 failures; iOS simulator build succeeded (2026-05-25). Best-effort QA documented at `docs/qa/2026-05-25-ios-gif-keyboard-best-effort-qa.md`.
- `todos/037` — added an internal/testable `DocumentLoader` injection seam to `JasonetteViewModel` URL initializers and a URLProtocol-backed ViewModel test proving normal non-seed URL loads set `documentURL` to the final response URL from `DocumentLoader.LoadedDocument.url`, then render the loaded document. Full Swift suite: 479 tests, 0 failures (2026-05-24).
- `todos/022` — footer input button `AsyncImage` now renders a visible `photo` SF Symbol placeholder on `.failure` while keeping `.empty` as `Color.clear` for the small 24x24 loading state. Full Swift suite: 478 tests, 0 failures (2026-05-24).
- `todos/038` — added `TabDescriptor(from:baseURL:)` coverage proving absolute non-hierarchical app URLs like `mailto:test@example.com` remain absolute when an HTTPS base URL is supplied. Existing app-scheme allowlist coverage remains intact. Full Swift suite: 478 tests, 0 failures (2026-05-24).
- `todos/036` — non-tab image renderers now apply `DocumentLoader.allowedSchemes` (`http`/`https`) after relative URL resolution. This covers `ImageComponent`, `ButtonComponent`, footer input buttons, and legacy inline footer tab icons, rejecting `file:` and custom schemes consistently while preserving authored relative HTTP(S) images. Added URLResolutionTests for representative allowed/rejected cases. Full Swift suite: 477 tests, 0 failures (2026-05-24).
- `todos/018` — `ComponentView` now constructs `ButtonComponent` through a `JasonComponent` initializer that uses `component.imageURL`, so authored `image` fields are honored for button image fallback while preserving `url` precedence. Added URLResolutionTests coverage for an image-only button. Full Swift suite: 473 tests, 0 failures (2026-05-24).
- `todos/021` — added ViewModel flow-through tests for `rgba(10,20,30,0.5)` and `#112233cc` body backgrounds. Full Swift suite: 473 tests, 0 failures (2026-05-24).
- `todos/045` implementation + QA — replaced the prior map placeholder path with `MapComponent` backed by SwiftUI/MapKit; `JasonComponent` now decodes `region` and `pins`; `JasonStyle.selected` decodes/merges for selected pin callouts; authored `coord`, width/height meter spans, pin title/description, and selected callout semantics are honored. Added ComponentDispatchTests for map decoding, registry knowledge, coordinate parsing, region creation, and annotations; added StyleModifierTests for `selected`; added ViewModel fixture coverage for `Jasonpedia/view/component/map/index.json`. Full Swift suite: 470 tests, 0 failures. Simulator QA on 2026-05-23 confirmed the Jasonpedia map fixture renders native maps and a pin-focused QA fixture renders a red pin plus visible title/description callout; see `docs/qa/2026-05-23-ios-map-component-qa.md` and artifacts under `docs/qa/artifacts/2026-05-23-ios-map-component/`.
- `todos/041` implementation + QA — added `HTMLComponent` backed by `WKWebView` for inline `text` + optional `css` and URL-backed `url` HTML; `JasonComponent` now decodes `css`; `ComponentView` dispatches `type: "html"`; relative URL-backed HTML resolves against `documentURL` with http/https allowlist; added ComponentDispatchTests for decoding, registry knowledge, HTML wrapping/CSS injection, relative URL resolution, and disallowed schemes plus a ViewModel fixture test for `Jasonpedia/view/component/html/index.json`. Full Swift suite: 462 tests, 0 failures. Simulator QA on 2026-05-23 confirmed the HTML fixture renders the article image, styled text, and links without `[Unknown: html]`; see `docs/qa/2026-05-23-ios-html-component-qa.md`.
- `todos/042` implementation — legacy inline footer tabs now maintain local selected index, show a selected capsule indicator for icon-only tabs, and expose non-empty accessibility labels with authored text first and per-position fallback labels for icon-only tabs; shell-mounted footer tabs also expose fallback labels and selected accessibility values. Added URLResolutionTests for label fallback behavior. User confirmed tabs are good in TestFlight once the fix was included.
- Build 52 follow-up — TestFlight still pushed duplicate views when tapping legacy inline `footer.tabs` items whose target is the current document (e.g. pushed Jasonpedia `core/href/tabs.json`). Root shell tabs and action-href tab switching were already fixed, but pushed/single-stack legacy footer tabs still used the old synthesized-href path. `FooterTabItemView` now no-ops current-document targets after relative resolution/standardization, preserving different-target navigation; added URLResolutionTests coverage. User later confirmed the fixed tabs are good in TestFlight.
- `todos/040` implementation — `JasonStyle.secure` now decodes/merges and `TextFieldComponent` routes `style.secure` truthy values plus legacy `type: "secure"` through SwiftUI `SecureField` while preserving `StateManager` binding and initial-value behavior; added ComponentDispatch, StyleModifier, and Jasonpedia textfield fixture tests. Simulator direct-fixture screenshot confirms the textfield page loads, and user later confirmed typed secure textfield behavior is now correct in TestFlight/simulator. Also wrote `~/jasonette-ios-simulator-qa-findings-2026-05-18.md` summarizing the QA methodology, tool commands, prompts, and findings.
- `todos/039` implementation — `#each` now merges object item fields into the per-item template context so original Jasonette direct identifiers like `{{title}}`/`{{url}}` render while preserving `{{$jason}}`, `this`, `$index`, and `$root`; added TemplateEngine regression coverage for object-form `items`, nested components, non-array empty output, plus ViewModel tests against `Jasonpedia/template/index.json` and `Jasonpedia/action/network/index.json`. Simulator direct-fixture screenshots confirm the Template and `$network` blank-list regressions are gone; see `docs/qa/2026-05-20-ios-simulator-post-fix-qa.md`.
- `todos/025` — footer tab-bar style/icon parity: shell tab cells now consume inherited/inline tab style, show selected tint + indicator, render `system://` SF Symbols without `AsyncImage`, and keep network-image failure placeholders.
- `todos/026` — action-tab dispatch: action-only footer tabs now construct/render, taps forward to the selected tab's active `JasonetteViewModel` action dispatcher, and `$href` action tabs targeting existing tabs switch instead of push; no-selectable action-only footers remain single mode.
- iOS simulator QA notes added at `docs/qa/2026-05-18-ios-simulator-complete-qa.md`; process notes added at `docs/qa/README.md`; compounded learnings added at `docs/solutions/best-practices/agent-device-ios-simulator-exploratory-qa.md`. `agent-device` 0.14.9 works for Simulator driving (`npx --yes agent-device@latest ...`). Key findings/follow-ups from this QA sequence are tracked as todos/039-047.

Nice-to-have (P3):
- none currently tracked as open

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

## Solution Docs (46 total, category dirs plus legacy root docs)

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
- `build-errors/android-json-decimal-exponent-number-policy.md` — Android decimal/exponent JSON numbers are explicitly `Double` by current cross-platform policy; exact plain integers still preserved

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
