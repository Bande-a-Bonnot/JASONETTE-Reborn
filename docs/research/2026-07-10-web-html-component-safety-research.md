---
date: 2026-07-10
topic: Web HTML component template and sandbox boundary
head_sha: f197d2c5ed7a1d6e6b1d752eee78693acad37a9e
agents: [ios-scout, android-scout, web-scout]
model: openai-codex/gpt-5.6-sol
thinking: xhigh
---

# Research: Web HTML Component Template and Sandbox Boundary

## Codebase Context

Jasonette Reborn has three current platform implementations and bundled legacy
references:

- Current iOS: `JASONETTE-iOS/JasonetteApp/`
- Legacy iOS: `JASONETTE-iOS/app/`
- Current Android: `JASONETTE-Android/JasonetteApp/`
- Legacy Android: `JASONETTE-Android/app/`
- Current Web: `packages/web-renderer/` and `packages/template-engine/`
- Legacy Web: `Jasonette-Web/`

The Web renderer uses TypeScript, Vitest/jsdom, and Vite. A document template is
transformed by `@jasonette/template-engine`, then component objects are handed to
`renderComponent()` for DOM creation.

## Fresh Cross-Platform Audit

Three dedicated read-only scouts were pinned to
`openai-codex/gpt-5.6-sol` with `xhigh` thinking and independently compared each
current platform against its bundled legacy implementation, Jasonpedia fixtures,
the v2 specification, and current tests at exact HEAD
`f197d2c5ed7a1d6e6b1d752eee78693acad37a9e`.

### iOS

The iOS scout ran:

```text
cd JASONETTE-iOS/JasonetteApp && swift test
```

Result: 612 tests passed, 0 failures. It found no P0 but identified material P1
residuals, including action return semantics, per-URL cache isolation, alert
forms, lifecycle hooks, navigation options/params, and header title/visibility.
Its smallest recommended iOS slice is header title/visibility parity because it
affects at least 26 bundled fixtures.

### Android

Android local Gradle remains blocked by the host toolchain. Default `java` is
missing; `/opt/homebrew/opt/openjdk/bin/java` is Java 25.0.2, and Gradle 8.11.1
fails before task execution with `25.0.2`. The scout therefore made no local test
claim. It found no P0 but identified P1 residuals in real `$reload` refetching,
rendering/style/layer fidelity, web backgrounds, navigation, lifecycle, and
per-URL cache isolation. Its smallest recommended Android slice is genuine
`$reload` refetching with stale-response protection.

### Web

The Web scout ran template-engine tests (141/141 passed), both TypeScript checks,
and temporary-output builds successfully. In the full Web suite, non-CLI tests
passed but CLI subprocess tests remained timing-sensitive under the parallel
suite; isolated CLI tests passed. It identified two P0 security findings:

1. `html.text` is passed through generic recursive template interpolation.
2. HTML component iframes are created without a sandbox attribute.

It also identified P1 timer, renderer-listener isolation, navigation/lifecycle,
action/state, mixin wiring, footer, and stylesheet-export gaps. The HTML boundary
is selected first because it is the only small, high-confidence P0 slice and is
fully testable without native SDKs or product-policy expansion.

## Existing Work

- `todos/069-complete-p2-web-html-component-inline-css.md` added authored inline
  CSS support for Web HTML components.
- `todos/070-complete-p2-web-body-background-webcontainer.md` added HTML body
  background support.
- `todos/102-complete-p2-web-session-global-actions.md` is the most recent Web
  runtime slice and is already pushed/CI-gated; this work must not reopen it.
- `docs/solutions/workflow-issues/foundry-adversarial-red-green-information-barrier.md`
  requires strict Foundry red/green context separation.

## Relevant Code

### Template transformation

`packages/template-engine/src/transformer.ts` recursively transforms every
string in an object. `processObject()` currently has no component-aware exception,
so an object such as:

```json
{
  "type": "html",
  "text": "<p>{{secret}}</p>",
  "style": { "height": "{{height}}" }
}
```

interpolates both `text` and `style.height`. The protocol requires the second
binding to remain template-capable while preserving `html.text` literally.

### Component rendering

`packages/web-renderer/src/components/index.ts` creates an iframe for both
inline `text` and URL-backed HTML. The inline branch uses `srcdoc` and escapes
closing `style` tags in authored CSS, but neither branch sets `sandbox`.

### Renderer integration

`packages/web-renderer/src/renderer.ts` calls `renderSync()` on body templates
before `renderItem()`/`renderComponent()`. Therefore the raw-HTML exemption must
happen before generic recursive interpolation reaches `html.text`; the component
renderer cannot recover the original string afterward.

## Protocol and Reference Behavior

`spec/jason-v2.0.md` sections 5.7 and 14.5 state:

- `html.text` is raw HTML.
- Template expressions MUST NOT be evaluated inside `html.text`.
- Implementations SHOULD sandbox HTML rendering.

Jasonpedia HTML/webcontainer fixtures contain executable scripts and nested
iframes, so disabling scripts entirely would regress legacy capability. An opaque
sandbox that allows scripts but omits `allow-same-origin` preserves interactive
HTML while blocking same-origin access to the parent DOM/storage.

## Test Landscape

Existing useful tests:

- `packages/template-engine/test/transformer.test.ts` covers recursive string
  interpolation and directives.
- `packages/web-renderer/test/components.test.ts` covers inline HTML `srcdoc`,
  authored CSS, and URL-backed iframe creation.
- `packages/web-renderer/test/integration.test.ts` covers the Jasonpedia HTML
  component and webcontainer/feed fixtures.

Missing tests:

- Literal preservation of `{{...}}` inside `html.text`.
- Continued interpolation of sibling HTML-component fields.
- Sandbox tokens for inline and URL-backed HTML.
- End-to-end transformation plus component rendering through a real document
  template.
- Retention of authored script content in `srcdoc`.

## Approaches Considered

### 1. Body-scoped component exception plus opaque script sandbox — selected

Add an opt-in body-template transform mode. In that mode, resolve object keys and
the component `type` first; when the resolved type is exactly `html`, preserve
the value whose resolved key is `text` and transform all other values normally.
The Web renderer enables this mode only for body templates, so generic action
option/data transforms retain existing behavior. Set the iframe sandbox to
exactly `allow-scripts` for inline and URL-backed HTML before assigning either
`srcdoc` or `src`. Apply the same sandbox to HTML body backgrounds because the
same document author controls both equivalent raw-HTML paths.

Benefits: closes the protocol violation before interpolation, handles dynamic
component types without changing generic transforms, maintains ordinary
bindings, preserves legacy script capability, and denies same-origin privilege.

### 2. Skip all templating for HTML component objects — rejected

This would also freeze safe sibling properties such as dimensions, CSS, URL,
class, and action metadata. It is broader than the protocol requirement and
would create avoidable parity regressions.

### 3. Disable all scripts with an empty sandbox — rejected

This is the strongest default isolation but breaks bundled animated/game/embed
fixtures and conflicts with the feature-parity objective.

### 4. Allow scripts and same-origin — rejected

`allow-scripts allow-same-origin` would let same-origin `srcdoc` content remove
or escape meaningful sandbox protections and access parent-origin data.

## Open Questions

### Resolved

- **Should `html.text` interpolate?** No; preserve it byte-for-byte.
- **Should sibling fields interpolate?** Yes; only raw HTML text is exempt.
- **Should the exception affect generic action/data transformation?** No; the
  Web renderer opts into protection only while rendering body templates.
- **Can jsdom prove browser sandbox enforcement?** No; focused tests verify the
  emitted policy and source-assignment order. Opaque-origin enforcement is a
  browser-platform assumption until real-browser acceptance infrastructure is
  introduced.
- **Should scripts run?** Yes, inside an opaque origin for legacy fixture parity.
- **Should URL-backed HTML be sandboxed too?** Yes; the HTML component boundary
  is consistent regardless of source.
- **Should body-background webcontainers change in this slice?** Yes. Their raw
  `html.text` values participate in body-template protection, and their iframes
  receive the same opaque script sandbox. Leaving this equivalent author-owned
  path unsandboxed would bypass the component boundary.

### Deferred

- A configurable iframe capability policy (`allow-forms`, navigation, downloads,
  popups) is deferred until a concrete fixture or product requirement needs it.
- Full AD-10/AD-11 URL/origin policy remains a separate larger security slice.
- CSP, iframe `referrerpolicy`, and `allow` permission policy are future hardening.
