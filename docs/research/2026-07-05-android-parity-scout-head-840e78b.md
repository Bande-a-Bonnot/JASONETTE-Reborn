---
date: 2026-07-05
topic: Android parity scout after runtime/action baseline slices
head_sha: 840e78b62b5a437aaa9e8a42aaaf52b8664e7179
agent: scout
model: openai-codex/gpt-5.5
thinking: xhigh
---

# Android Parity Scout at `840e78b`

## Scope

Dedicated read-only Android parity inspection requested by the active
cross-platform parity goal. The scout compared current Android code under
`JASONETTE-Android/JasonetteApp/` with the legacy Android reference under
`JASONETTE-Android/app/`, after completed Android slices `todos/068` and
`todos/075`-`todos/078`.

## Current Implemented Android Capabilities

- `ActionDispatcher.kt` recognizes `$set`, `$get` as state-context no-op,
  `$flush`, `$cache.set`, `$cache.get`, `$cache.reset`, `$render`, `$reload`,
  `$network.request`, `$href`, `$util.alert`, `$util.toast`, `$util.banner`,
  `$log`/`$log.info`/`$log.debug`/`$log.error`, and named `trigger` dispatch.
- `DocumentLoader.kt` performs URL loading plus legacy `+`/`@` include
  preprocessing, selector includes, `$document` references, and HTTP(S) guards.
- `JasonetteDocumentRenderer.kt` renders the body template and exposes `$jason`,
  `$get`, `$cache`, and `$response` to template contexts.
- `ComponentView.kt` renders label, image, button, textfield, textarea, slider,
  space, switch, vertical, and horizontal components. Map and HTML remain visible
  placeholder/stub paths.
- JVM tests cover dispatcher, document loader, template/expression rendering,
  renderer context, footer rendering, style/color, state, and JSON conversion.
  No Android Compose UI instrumentation suite is currently present.

## Remaining Gaps Ranked by Scout

### P1

1. **Navigation is not wired in the app.**
   - Current: `MainActivity.kt` created `JasonetteScreen(url=...)` without an
     `onNavigate` handler; `$href` only called the optional dispatcher callback.
   - Reference: `JasonViewActivity.java` supports `$href` navigation, replacement,
     tab switching/preload, `$back`, and `$close`.
2. **Render/action graph is still narrow.**
   - Current: `JasonTemplates` only models `body`, and `JasonAction` only models
     object `options` plus single `success`/`error` actions.
   - Reference: legacy Android supports action arrays, broader option parsing,
     `trigger`/`$lambda`, `$return.*`, and `$render` template/data selection.

### P2

- Native/common action families remain mostly missing: `$audio`, `$media`,
  `$geo`, `$timer`, `$script`, `$convert`, `$vision`, `$util.picker`,
  `$util.datepicker`, `$util.addressbook`, `$util.share`, `$network.upload`, and
  extended service/session/global families.
- Map/html/body background/header parity remains incomplete. Current map/html
  render placeholder text and the screen does not render `body.header` or
  `body.background` with legacy behavior.

### P3

- Extended services/platform parity remains open: `$oauth`, `$push`,
  `$websocket`, `$agent`, `$global`, `$session`, richer lifecycle hooks, and
  emulator/UI verification. Local Gradle remains blocked by the host's missing
  Java runtime, so CI is the Android verification source of truth.

## Suggested Next Atomic Todos

1. Android navigation stack + `$back`/`$close` wiring.
2. Android flexible action/render graph: named templates, `$render options.data`
   and `options.template`, `$lambda`/`$return`, action arrays/string options.
3. Follow with targeted P2 slices such as `$timer.start`/`$timer.stop`, or
   map/html/background/header fixture parity.

## Parent Follow-up

The first suggested slice was implemented immediately after this scout as
`todos/079`: `MainActivity` now provides a simple Compose URL stack, `$href`
navigation reaches the app, `replace` transitions swap the current stack entry,
and `$back`/`$close` dispatch to back/finish handlers.

The second suggested slice was implemented as `todos/080`: Android now decodes
arbitrary named `head.templates`, passes `$render.options.template` and
`$render.options.data` through the dispatcher, renders selected templates with a
`body` fallback, and exposes render data as `$jason` plus top-level fields.
