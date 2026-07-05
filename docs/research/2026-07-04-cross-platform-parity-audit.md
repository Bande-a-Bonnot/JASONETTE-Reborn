---
date: 2026-07-04
topic: Jasonette cross-platform feature parity
---

# Research: Jasonette Cross-Platform Feature Parity

## Scope

Objective: compare current Jasonette-Reborn implementations against the legacy
Jasonette iOS, Android, and Web projects, identify capability/test gaps, and
triage next parity work.

Current/reference trees in this repository:

- iOS current: `JASONETTE-iOS/JasonetteApp/`
- iOS reference: `JASONETTE-iOS/app/`
- Android current: `JASONETTE-Android/JasonetteApp/`
- Android reference: `JASONETTE-Android/app/`
- Web current: `packages/web-renderer/`, `packages/template-engine/`
- Web reference: `Jasonette-Web/`

Generated/cache/build artifacts such as `.gradle/`, `build/`, `.build/`,
`DerivedData/`, `node_modules/`, and generated Xcode projects are excluded from
this audit.

## Delegation and Verification Notes

- iOS parity scout completed after the subagent tool accepted the requested
  `openai-codex/gpt-5.5` / xhigh routing and returned a read-only report.
- Web parity scout completed after the subagent tool accepted the requested
  `openai-codex/gpt-5.5` / xhigh routing and returned a read-only report.
- Android gpt-5.5 scout could not run during the initial 2026-07-04 audit: the
  subagent backend reported no available `openai-codex/gpt-5.5`
  credentials/model match, so initial Android findings below came from a local
  read-only audit using source files only. A refreshed dedicated Android parity
  scout later succeeded with `openai-codex/gpt-5.5` / xhigh at HEAD `840e78b`;
  see `docs/research/2026-07-05-android-parity-scout-head-840e78b.md`.
- Current local Android Gradle verification remains unavailable: `java -version`
  fails with `Unable to locate a Java Runtime`.
- Repo status before writing this artifact was clean on `main...origin/main`.

## Current Implementation Snapshot

### iOS current

Evidence:

- `docs/HANDOFF.md` lists 12 current components and the current action matrix.
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/ActionDispatcher.swift`
  dispatches state/cache/render/nav/network/convert/util/media/geo/vision/script/log/timer.
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/ComponentRegistry.swift`
  routes label/image/button/textfield/secure/textarea/slider/switch/space/map/html/vertical/horizontal.
- `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/` contains targeted action,
  component, view-model, URL, template, style, and cross-platform tests.

Implemented breadth is strongest on iOS: native media/camera/picker/play/share,
addressbook, geo, vision, map, html, tabs/navigation, style compatibility,
Jasonpedia fixture regressions, and TestFlight provenance are all represented in
current code/tests.

### Android current

Evidence:

- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/MainActivity.kt`
  renders `JasonetteScreen` against the hosted Jasonpedia demo URL.
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/rendering/JasonetteScreen.kt`
  renders top app bar, sections, layers, and retry/loading states via Jetpack
  Compose.
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/components/ComponentView.kt`
  supports label, image, button, textfield, textarea, slider, space, switch,
  map stub, vertical, and horizontal.
- `JASONETTE-Android/JasonetteApp/app/src/main/java/com/jasonette/rendering/ActionDispatcher.kt`
  implements only `$set`, `$get` no-op, `$cache.set`, `$cache.get` no-op,
  `$cache.reset`, `$render` no-op, `$reload` no-op, and basic
  `$network.request`.
- `JASONETTE-Android/JasonetteApp/app/src/test/java/com/jasonette/` covers
  template, expression, document loading, style, state, JSON value conversion,
  and basic action dispatch.

Android current is a small Compose renderer with a useful core/template/test
foundation but a much narrower runtime/action/component surface than both legacy
Android and current iOS.

### Web current

Evidence from the web scout:

- `packages/web-renderer/src/renderer.ts` fetches/renders documents, stores
  `head.styles`/`head.actions`, renders body/header/sections/layers/footer, and
  fires `$load`/`$show`/visibility hooks.
- `packages/web-renderer/src/components/index.ts` supports label, button, image,
  textfield, textarea, html, slider, space, switch; map is a visible stub.
- `packages/web-renderer/src/actions/index.ts` registers `$render`, `$reload`,
  `$network.request`, `$set`, `$get`, `$cache.*`, `$flush`, `$util.alert`,
  `$util.toast`, `$util.banner`, `$timer.start`, `$timer.stop`, `$log`, and
  `$lambda`.
- `packages/template-engine/src/` supports `{{ }}`, `#each`, `#if/#elseif/#else`,
  and a safe expression allowlist.

Web current already exceeds the legacy web README's old MV-only statement in
some action areas, but it still lacks key action activation, render context, and
fixture parity paths.

## Major Parity Gaps

### 1. Legacy document preprocessing / includes

Legacy iOS/Android resolved `+`, `@`, `$require`, and local/remote references
before rendering:

- iOS reference: `JASONETTE-iOS/app/Jasonette/Jason.m`
- Android reference: `JASONETTE-Android/app/src/main/java/com/jasonette/seed/Core/JasonModel.java`
  and `JasonRequire.java`
- Web reference: `Jasonette-Web/src/mixin.js`

Current iOS only handles a narrow `head.data["@"]` path; current Android has no
include/preprocessing support; current web has template-engine mixin support but
does not fully wire remote `head.data @` into renderer fetch/render.

Impact: webcontainer, feed, iframe/pdf, shared template/style, and Jasonpedia
fixtures using `+`/`@` under-render or cannot load equivalent documents.

### 2. Web action activation and render data propagation

Current web gaps from scout report:

- Component `action` / named `trigger` is not wired from rendered items.
- `$render` ignores incoming success payload and `options.template`.
- Contexts omit important Jasonette variables such as `$get`, `$cache`,
  `$params`, and `$response` in several render paths.
- `$href`, `$back`, and `$close` actions are not registered.

Impact: many action/template fixtures cannot drive UI changes even when the
static component renderer works.

### 3. Android action/runtime parity

Legacy Android action classes include `$audio`, `$media`, `$util`, `$geo`,
`$vision`, `$network.upload`, `$oauth`, `$push`, `$session`, `$global`,
`$websocket`, `$agent`, `$return`, `$convert`, `$script`, `$timer`, and cache/log
families under `JASONETTE-Android/app/src/main/java/com/jasonette/seed/Action/`.

Current Android `ActionDispatcher.kt` only implements state/cache basics and a
minimal `$network.request`, with `$render`/`$reload` noted as no-ops handled by
ViewModel but not yet wired to re-render in `handleAction`.

Impact: Android is currently the furthest from runtime parity.

### 4. Component event semantics

Legacy iOS/Android components fire authored actions on control changes or taps,
including text fields, textareas, sliders, switches, maps, and footer items.

Current partials:

- iOS control state binding exists, but scout identified action callbacks for
  textfield/textarea/slider/switch as partial.
- Android components store state for controls but do not execute authored control
  actions on value changes.
- Web components need action/trigger dispatch wiring.

Impact: Jasonpedia component demos that expect UI controls to drive `$set`,
`$render`, or named actions remain incomplete.

### 5. Advanced webcontainer / HTML bridge / backgrounds

Legacy iOS/Android include webcontainer/agent services and HTML bridges:

- iOS reference: `JasonHtmlComponent.m`, `JasonAgentAction.m`, related services.
- Android reference: `JasonHtmlComponent.java`, `JasonAgentAction.java`,
  `Service/agent/JasonAgentService.java`.
- Web reference supports HTML/web backgrounds in `Jasonette-Web/src/web.js`.

Current gaps:

- iOS `HTMLComponent` renders content but lacks the legacy Jason bridge.
- Android current has no HTML component and no agent/webcontainer service.
- Web current HTML ignores separate `css`; background handling is string-only.

Impact: webcontainer and agent demos are not parity-complete.

### 6. Navigation and lifecycle hooks

Current gaps:

- iOS lacks some legacy navigation options such as `replace`, `fullscreen`,
  `fresh`, `preload`, and custom/native controller semantics.
- Android current only exposes an `onHref` callback from `JasonetteScreen`; no
  full navigation stack/action parity is evident.
- Web current lacks `$href`/`$back`/`$close` action registration despite a public
  `back()` method.
- Legacy lifecycle hooks `$show`, `$foreground`, `$background` are not uniformly
  implemented across platforms.

## Test Landscape and Gaps

### Existing useful checks

- iOS: `cd JASONETTE-iOS/JasonetteApp && swift test`
- Android: `cd JASONETTE-Android/JasonetteApp && ./gradlew test` once Java 17 is
  available locally; currently rely on CI for Android Gradle verification.
- Web: `npm run test --workspace=@jasonette/web` and package-specific Vitest
  suites.

### High-value new tests

- Cross-platform fixture parity smoke tests for selected Jasonpedia files:
  - `Jasonpedia/view/footer/tabs.json`
  - `Jasonpedia/view/footer/input.json`
  - `Jasonpedia/view/component/slider/index.json`
  - `Jasonpedia/view/component/html/index.json`
  - `Jasonpedia/view/component/map/index.json`
  - `Jasonpedia/view/background/index.json`
  - `Jasonpedia/view/layer/dynamic.json`
  - `Jasonpedia/action/network/eliza.json`
  - `Jasonpedia/webcontainer/pdf.json`
  - `Jasonpedia/webcontainer/feed/index.json`
- Web Vitest tests for action/trigger dispatch, `$network.request` success into
  `$response`, and `$render` with `options.template`.
- Android unit tests for `$href` decode/dispatch, `$render` re-rendering after
  `$set`, footer rendering, and map/html placeholder parity before native work.
- iOS tests for top-level `+` include resolution and control action callbacks.

## Triage

### P0/P1 next work

1. **Web UI action/render parity** — unblock click-driven demos and template
   render chains first because the code surface is smaller than native media.
   Completed todo: `todos/066-complete-p1-web-action-render-parity.md`.
2. **iOS legacy include preprocessing** — iOS is otherwise strong; `+`/`$require`
   support would unlock webcontainer/shared-template fixtures.
   Completed todo: `todos/067-complete-p1-ios-legacy-include-preprocessing.md`.
3. **Android runtime parity baseline** — implement a narrow Android pass for
   navigation/action re-render/render-context behavior before native media.
   Candidate todo: `todos/068-p1-android-runtime-parity-baseline.md`.

### P2 follow-up work

4. Cross-platform control event semantics for textfield/textarea/slider/switch.
5. Webcontainer/HTML bridge/background parity.
6. Android native action families (`$util`, `$media`, `$geo`, `$vision`, audio,
   session/global/websocket/agent) after baseline rendering/action parity.

## Open Questions

- Whether to prioritize cross-platform fixture parity infrastructure before
  implementing individual features. The current audit suggests yes for web and
  Android, where fixture failures would guide the large surface area.
- Whether the legacy web project should remain the reference for web parity or
  whether current web should target iOS/Android current behavior where legacy web
  never implemented actions.
- Whether `agent-device` should remain the iOS interactive QA target or be
  replaced/augmented with a different automation path due to persistent XCTest
  runner instability.
