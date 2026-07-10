---
date: 2026-07-10
topic: Web HTML component template and sandbox boundary
status: active
research: docs/research/2026-07-10-web-html-component-safety-research.md
---

# Specification: Web HTML Component Template and Sandbox Boundary

## Problem Statement

The current Web renderer recursively evaluates template expressions inside every
string in a body template, including privileged `html.text` raw markup. It then
renders inline and URL-backed HTML in iframes without a sandbox attribute. This
violates the v2 raw-HTML boundary and lets authored HTML receive more browser
privilege than required. The renderer must preserve raw HTML in body templates
while continuing to template ordinary fields, then emit an opaque,
script-capable iframe sandbox policy before assigning any iframe source.

## Actors and Boundaries

- **Document author:** supplies body templates and HTML components.
- **Template engine:** evaluates Jasonette bindings and structural directives.
- **Web renderer:** opts into HTML raw-text protection only for body templates.
- **HTML component renderer:** converts a transformed component into an iframe.
- **Browser:** enforces the emitted iframe sandbox policy.
- **Host page:** owns application state, DOM, and storage outside the iframe.

The template engine remains generic by default. A new opt-in body-template mode
classifies HTML component objects while recursively transforming body roots,
sections, layouts, layers, headers, footers, and values produced by `#if` or
`#each`. Generic transformations used for action options, payloads, data, and
other callers do not enable the mode and retain existing behavior.

Raw `html.text` values inside `body.background` participate in body-template
protection because they are part of the recursively transformed body tree. The
separate body-background iframe creation/sandbox policy, generic URL validation,
CSP, and native-platform HTML components are outside this slice.

## Vocabulary

- **Body-template mode:** an opt-in `RenderOptions` flag named
  `preserveHtmlText`; it defaults to `false`.
- **Resolved key:** an authored object key after existing key interpolation.
- **Resolved type:** the transformed value assigned by the last object entry
  whose resolved key is `type`.
- **Raw text entry:** an object entry whose resolved key is `text` when the
  resolved type is the exact string `html`.
- **Opaque script sandbox policy:** the exact iframe attribute
  `sandbox="allow-scripts"`; it excludes `allow-same-origin` and every other
  sandbox capability token.

## Requirements

- **R1. Explicit body scope.** `preserveHtmlText` MUST default to `false`. The Web
  renderer MUST set it to `true` when transforming a selected body template in
  both initial rendering and `$render` re-rendering. Existing action, option,
  payload, and standalone generic transforms MUST retain the default.
- **R2. Deterministic classification.** In body-template mode, regular-object
  keys MUST first resolve in authored insertion order. Values assigned to
  resolved key `type` MUST transform normally. The last such entry wins, matching
  JavaScript object assignment. Only the exact resolved string `html` activates
  raw-text protection. Objects returned by directives and objects nested in
  arrays/layouts MUST use the same rule.
- **R3. Literal raw value.** When protection is active, each raw text entry MUST
  be copied without value transformation, evaluation, coercion, normalization,
  or recursive traversal. For a string, the output value MUST be strictly equal
  (`===`) to the input JavaScript string. For a non-string, the original value
  reference/value MUST be retained by the transformer.
- **R4. Resolved-key collisions.** Entries MUST be assigned to the output object
  in authored insertion order; the last entry for a duplicate resolved key wins.
  If the resolved type is `html`, every entry whose resolved key is `text` is
  copied raw before normal last-write-wins assignment. Templated keys therefore
  receive the same protection as literal keys.
- **R5. Narrow exception.** Every entry other than a protected raw text entry
  MUST continue through existing transformation. A non-HTML object with a
  `text` key MUST continue to interpolate. The same object transformed with
  `preserveHtmlText: false` MUST retain existing generic interpolation.
- **R6. Sandbox before source.** Every iframe created by the HTML component,
  whether inline or URL-backed, MUST follow this exact security-relevant operation
  order: create iframe; set exactly `sandbox="allow-scripts"` as the first
  operation on that iframe; assign `srcdoc` or `src`; apply non-security styling;
  append to the detached HTML wrapper; return the wrapper. No iframe operation
  may occur between creation and sandbox assignment. The renderer MUST NOT later
  remove or expand the policy.
- **R7. Exact source composition.** CSS is present only when its transformed
  value is a non-empty string; empty strings, `null`, `undefined`, and non-string
  values are treated as absent. Without CSS, inline `srcdoc` MUST equal the
  authored HTML string. With CSS, `srcdoc` MUST equal
  `<style>${escaped_css}</style>${html}`. `escaped_css` replaces every
  case-insensitive occurrence matching `</style` with an eight-code-unit runtime
  sequence: U+003C (`<`), U+005C (backslash), U+002F (`/`), then lowercase
  `style`. All other CSS and all HTML remain unchanged. URL-backed HTML MUST use
  `src`, leave `srcdoc` empty, and ignore inline CSS.
- **R8. Deterministic source selection.** Truthy `text` takes precedence over
  `url` and is converted with existing `String(text)` behavior by the component
  renderer. Empty string, `null`, and `undefined` fall through to a truthy `url`.
  Whitespace-only text is truthy and selects inline `srcdoc`. If neither source
  is truthy, the HTML wrapper contains no iframe. Malformed/non-string type
  values do not activate protection.
- **R9. Testable claims only.** Automated jsdom tests MUST verify transform
  outputs, exact sandbox tokens, sandbox-before-source assignment, and source
  strings. They MUST NOT claim to prove browser script execution or opaque-origin
  enforcement; browser enforcement is an explicit platform assumption.

## Behaviors

### Behavior: Transform a body-template object

- **Trigger:** `transform()` encounters a regular object with
  `preserveHtmlText: true` anywhere under the body-template root, including
  arrays and directive results.
- **Input:** Object entries, render context, and options.
- **Process:**
  1. Resolve every key in insertion order using existing key interpolation.
  2. Transform values for all entries whose resolved key is `type` and determine
     the last assigned resolved type.
  3. Iterate the entries in insertion order. Reuse the transformed type value
     for `type` entries. If resolved type is `html` and resolved key is `text`,
     copy the original value. Otherwise transform the value normally.
  4. Assign each value under its resolved key; later collisions overwrite earlier
     values.
- **Output:** A transformed object with a literal raw HTML value only when the
  resolved semantic component type is `html`.
- **Errors:** Existing evaluator behavior for unresolved expressions remains
  unchanged. If type resolution does not produce exact string `html`, no special
  handling occurs.

Authoritative vectors:

| Input and context | Mode | Exact relevant output |
|---|---:|---|
| `{type:"html", text:"<p>{{secret}}</p>", style:{height:"{{height}}"}}`; `{secret:"LEAK",height:40}` | on | `{type:"html", text:"<p>{{secret}}</p>", style:{height:40}}` |
| `{type:"{{kind}}", "{{slot}}":"<p>{{secret}}</p>"}`; `{kind:"html",slot:"text",secret:"LEAK"}` | on | `{type:"html", text:"<p>{{secret}}</p>"}` |
| `{"{{type_key}}":"{{kind}}", text:"{{secret}}"}`; `{type_key:"type",kind:"html",secret:"LEAK"}` | on | `{type:"html", text:"{{secret}}"}` |
| `{type:"html", "{{slot}}":"first", text:"second"}`; `{slot:"text"}` | on | `{type:"html", text:"second"}` |
| `{type:"label", text:"{{secret}}"}`; `{secret:"OK"}` | on | `{type:"label", text:"OK"}` |
| `{type:"html", text:"{{secret}}"}`; `{secret:"GENERIC"}` | off | `{type:"html", text:"GENERIC"}` |

### Behavior: Render inline HTML

- **Trigger:** `renderComponent()` receives resolved type `html` with truthy
  `text`.
- **Input:** Raw value and optional authored CSS.
- **Process:** Create the iframe, set the exact sandbox policy, compose and assign
  `srcdoc`, style the iframe, then append it to the detached wrapper.
- **Output:** A wrapper containing one iframe with inline content and no `src`.
- **Errors:** Invalid HTML is passed to browser parsing unchanged. No sanitizer or
  parser is introduced.

CSS golden vectors (the displayed backslash is a runtime U+005C code unit):

| HTML | CSS | Exact runtime `srcdoc` value |
|---|---|---|
| `<p>x</p>` | absent, `""`, `null`, `undefined`, or non-string | `<p>x</p>` |
| `<p>x</p>` | one space (`" "`) | `<style> </style><p>x</p>` |
| `<p>x</p>` | `</STYLE>` | `<style><\/style></style><p>x</p>` |
| `<p>x</p>` | `a</style>b</StYlE>c` | `<style>a<\/style>b<\/style>c</style><p>x</p>` |

Copyable JavaScript assertion (the source literal uses `\\` to encode one
runtime backslash):

```javascript
expect(htmlSrcdoc("<p>x</p>", "</STYLE>"))
  .toBe("<style><\\/style></style><p>x</p>");
```

### Behavior: Render URL-backed HTML

- **Trigger:** HTML component `text` is falsey and `url` is truthy.
- **Input:** Authored URL value.
- **Process:** Create the iframe, set the exact sandbox policy, assign `src`, style
  it, and append it to the detached wrapper.
- **Output:** One iframe with browser-coerced `src` and empty `srcdoc`.
- **Errors:** URL validation/network behavior remains unchanged.

### Behavior: Select an HTML source

| Resolved `text` | Resolved `url` | Result |
|---|---|---|
| non-empty string | any | inline iframe; text wins |
| whitespace-only string | any | inline iframe |
| truthy non-string | any | inline iframe using `String(text)` |
| `""`, `null`, `undefined`, `false`, `0`, or `NaN` | truthy | URL iframe |
| `""`, `null`, `undefined`, `false`, `0`, or `NaN` | falsey/missing | no iframe |

## Key Decisions

- **Body-mode opt-in, not a global semantic change.** This protects renderable
  body components without changing action/data transformations.
- **Resolved keys and type define classification.** Literal-only detection leaves
  dynamic semantic equivalents unprotected; insertion-order last-write-wins
  matches current output-object behavior.
- **Only raw text is exempt.** Skipping the whole component would regress dynamic
  style, dimensions, URL, class, and action fields.
- **Scripts are allowed only in an opaque sandbox.** Empty sandbox breaks bundled
  interactive fixtures; adding `allow-same-origin` weakens host isolation.
- **Policy emission is tested, browser enforcement is assumed.** The repository
  has jsdom but no real-browser acceptance harness; introducing Playwright is not
  required for this atomic slice.

## Scope Boundaries

- **In scope:** an opt-in template-engine mode, including raw-text protection
  for HTML objects under `body.background`; Web body-template call sites; Web
  HTML component iframe policy; unit/integration regression tests.
- **Out of scope:** changing the separate body-background iframe sandbox policy;
  HTML sanitization; CSP; permission/referrer policy; AD-10/AD-11
  URL/origin/redirect policy; native HTML components; agent bridges; new
  browser-test infrastructure.
- **Future:** a separately reviewed browser acceptance harness can verify script
  execution plus denied parent DOM/storage access. Additional sandbox tokens may
  be added only through an explicit capability and threat review.

## Success Criteria

- All authoritative transform, CSS, and source-selection vectors pass.
- Initial rendering and `$render` re-rendering both enable
  `preserveHtmlText: true`; a generic action/options transform demonstrates the
  default-off behavior.
- Transform tests cover nested arrays plus HTML objects produced by both `#if`
  and `#each`, and retain raw text in each case.
- Collision tests cover a later resolved `type` changing `html` to `label` (text
  transforms) and a later resolved `type` changing `label` to `html` (text stays
  raw), in addition to duplicate resolved `text` last-write-wins behavior.
- A non-string object used as protected `text` retains strict reference identity.
  Missing, unresolved, and non-string resolved types do not activate protection.
- A renderer integration document with a body template containing dynamic HTML
  type, raw `{{secret}}` markup, and dynamic sibling style renders the raw braces
  in iframe `srcdoc`, resolves the sibling style, and emits exactly
  `sandbox="allow-scripts"`. An ordinary label in the same document still
  interpolates.
- Instrumented order-sensitive tests cover both inline and URL branches and
  assert the complete trace `create iframe → set sandbox → assign srcdoc/src →
  style → append → return`, including that sandbox assignment is the first iframe
  operation. Token assertions reject `allow-same-origin` and every additional
  token.
- Source-selection tests cover non-empty, whitespace, empty, null, undefined,
  falsey non-string (`false`, `0`, `NaN`), truthy non-string, dual-source, and
  no-source inputs.
- CSS tests cover absent, empty, whitespace-only, null, undefined, non-string,
  one mixed-case closing-style sequence, and multiple mixed-case sequences using
  exact runtime equality.
- `Jasonpedia/view/component/html/index.json` retains CSS substring
  `img{width: 100%;}` and content substring `Nexus devices`. A synthetic renderer
  integration retains exact script substring
  `<script>window.__html_boundary = "{{secret}}"</script>` in `srcdoc`.
- Body-background HTML raw text is protected by the body transform. Its separate
  iframe retains the exact baseline `getAttribute("sandbox") === null`; changing
  that iframe policy is outside this slice.
- The following commands pass:

```text
npm run test --workspace=@jasonette/template-engine -- transformer.test.ts
npm run test --workspace=@jasonette/web -- components.test.ts integration.test.ts
npm run typecheck --workspace=@jasonette/template-engine
npm run typecheck --workspace=@jasonette/web
npm run build --workspace=@jasonette/template-engine
npm run build --workspace=@jasonette/web
npm run test --workspace=@jasonette/template-engine
npm run test --workspace=@jasonette/web
```

If the known local CLI subprocess timeout recurs only in the final full Web
suite, it remains a failure locally: rerun `cli.test.ts` for diagnosis and require
exact-SHA CI success before recording the slice as verified.

## Open Questions

### Resolved

- Scripts remain enabled only through the opaque sandbox.
- Dynamic/resolved keys and types participate in protection.
- Generic action/data transformations remain unchanged through default-off mode.
- jsdom verifies emitted policy, not browser enforcement.

### Deferred

- Real-browser sandbox enforcement and the body-background iframe sandbox policy
  require separate infrastructure/scope; raw-text protection already applies.
- Full URL/origin policy and future sandbox capabilities require separate specs.
