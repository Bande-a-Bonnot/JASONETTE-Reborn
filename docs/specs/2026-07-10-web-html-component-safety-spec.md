---
date: 2026-07-10
topic: Web HTML template and iframe safety boundary
status: active
research: docs/research/2026-07-10-web-html-component-safety-research.md
---

# Specification: Web HTML Template and Iframe Safety Boundary

## Problem Statement

The Web renderer evaluates every string in a body template, including privileged
`html.text`, and creates both HTML-component and HTML-background iframes without
a sandbox. Dynamic/resolved keys also flow into ordinary JavaScript object
assignment, where `__proto__` can mutate an output object's prototype. These
paths violate the v2 raw-HTML boundary and permit equivalent HTML sources to
receive inconsistent privilege. The renderer must preserve HTML raw values only
in an opt-in body-template mode, construct safe own-property outputs, and apply
an opaque script-capable sandbox before assigning any HTML iframe source.

## Actors and Boundaries

- **Document author:** supplies body templates, actions embedded in that tree,
  HTML components, and HTML backgrounds.
- **Template engine:** resolves keys, directives, and values.
- **Web renderer:** enables raw-text protection for body-template transforms,
  including initial rendering and `$render`.
- **HTML renderers:** construct component and background iframes.
- **Browser:** enforces the emitted `sandbox="allow-scripts"` policy.
- **Host page:** owns application DOM, state, and storage outside the iframes.

The raw-text classifier is deliberately **shape-based inside the complete body
tree**. Any regular object under the body root whose final resolved own `type`
value is exact string `html` protects resolved own `text` entries, including an
object nested inside action/options/payload data authored in that body tree.
Separate action/options/payload/data transforms invoked outside body rendering
remain generic because the option defaults off.

The body tree includes body roots, headers, footers, sections, layouts, layers,
backgrounds, nested arrays, and values emitted by `#if`, `#elseif`, `#else`, and
`#each`.

## Requirements

- **R1. Explicit body scope.** Add `RenderOptions.preserveHtmlText?: boolean`
  with effective default `false`. Initial and `$render` body-template transforms
  MUST pass `true`. `executeAction()` option/continuation transforms and direct
  standalone `transform()` calls omit the option and remain generic.
- **R2. Mode matrix.** In body mode, use all-keys-first classification: resolve
  all own enumerable string keys once in ECMAScript `Object.keys()` order, then
  transform resolved `type` values, then transform/retain output values. With the
  mode omitted/false, retain existing per-entry key-then-value evaluation order
  and do not pre-transform types. Safe own-property definition applies in both.
  A numeric-key vector MUST prove `Object.keys({"2":...,"1":...,alpha:...})`
  order `"1"`, `"2"`, `"alpha"` rather than source-text order.
- **R3. Literal raw values.** Under final type `html` in body mode, every entry
  whose resolved key is `text` MUST retain its original in-memory value without
  evaluation, coercion, normalization, or recursive traversal. String output
  MUST satisfy strict equality (`===`); object output retains reference identity.
- **R4. Deterministic safe output and state sinks.** Enumerate only own
  enumerable string keys in ECMAScript `Object.keys()` order. Later definitions
  win. In both modes, every result key—including `__proto__`, `constructor`, and
  `prototype`—MUST be an enumerable, writable, configurable own data property
  without prototype mutation. `$set`, `$cache.set`, and `$global.set` use the
  same safe-copy semantics. `$session.set` safely copies transformed options into
  a fresh stored-session object and safely defines that object under the normalized
  domain in `state.sessions`; both objects retain `Object.prototype`. Session
  lookup ignores inherited domains. HTML dispatch/rendering ignores inherited
  `type`, `text`, `url`, and `css`. Null-prototype source objects remain valid.
- **R4a. Own-callable registries.** Component and action dispatch select only an
  own registered function. Component missing/inherited/non-string type follows
  the existing label default; an own unknown/prototype-colliding string returns
  the visible unknown-component element. Action dispatch reads only own `type`
  and own `trigger`; inherited type is missing. A missing/non-string type with an
  own string trigger uses own-entry named-action lookup. `$lambda` uses the same
  lookup for `options.name`. Own named entries may be action objects or arrays;
  inherited entries are ignored. Own unknown/prototype-colliding action type
  returns `undefined` without a continuation. Background rendering requires own
  exact string `html`. No case invokes inherited members or throws.
- **R5. Shape-based body exception.** Resolved `type` values and all entries
  other than protected resolved `text` continue through normal transformation.
  Protection applies recursively everywhere in a body tree, including embedded
  action/options/payload objects. If such an embedded action later executes,
  `executeAction()` performs its existing second generic options transform; no
  new promise is made that raw values stay raw after that separate phase.
- **R6. Source domain and selection.** Only own non-empty string `text` or `url`
  values are valid sources. Non-string, empty, missing, and inherited values are
  ignored. Valid text wins over valid URL. This follows the protocol's string
  types and removes arbitrary JavaScript coercion from the boundary.
- **R7. Exact inline composition.** CSS is present only when the own transformed
  value is a non-empty string. Without CSS, `srcdoc === text`. With CSS, it
  equals `<style>${escaped_css}</style>${text}`. Every case-insensitive
  `</style` becomes U+003C, U+005C, U+002F, then lowercase `style`; everything
  else is unchanged.
- **R8. Sandbox both HTML iframe paths.** Every HTML component/background iframe
  MUST receive exact `sandbox="allow-scripts"`, without `allow-same-origin` or
  any additional token.
- **R9. Security order and endpoint state.** For each created iframe, sandbox
  assignment is the first security-observed operation and precedes every iframe
  parent insertion, source assignment, and renderer return. From creation through
  return, exactly one sandbox event occurs: the required initial set. Tests check
  exact sandbox endpoint state after initial render and after `$render`; no claim
  is made about continuous post-return mutation monitoring.
- **R10. Source-attribute exclusivity.** Inline mode has `srcdoc` and no `src`.
  URL mode has `src` and no `srcdoc`; an empty property is not equivalent to an
  absent attribute.
- **R11. Evidence boundary.** jsdom tests verify transformation, descriptors,
  prototypes, exact strings/attributes, and finite operation traces. They MUST
  NOT claim browser script execution or opaque-origin enforcement.
- **R12. Named regression behavior.** `components.test.ts` HTML class/size/border
  behavior and `integration.test.ts` rendered Jasonpedia CSS/content remain
  green. Invalid HTML is assigned unchanged. URL validation/network policy and
  real-browser coercion/security are outside this slice rather than claimed
  unchanged by jsdom.

## Behaviors

### Behavior: Transform a Body-Tree Object

- **Trigger:** `transform()` encounters a regular object.
- **Generic/off process:** Enumerate own enumerable string keys in insertion
  order. For each entry, resolve its key and immediately transform its value,
  preserving existing evaluation order. Define the result through safe own data
  property semantics from R4. Do not classify or protect HTML text.
- **Body/on process:**
  1. Resolve all authored keys exactly once in insertion order.
  2. Transform every value whose resolved key is `type`, in insertion order.
  3. Use the final such own value to classify the object.
  4. Iterate entries in insertion order. Reuse pre-transformed type values;
     retain resolved text values raw only under exact final type `html`; transform
     all other values normally.
  5. Define each resolved key as a safe own data property; later definitions in
     ECMAScript `Object.keys()` order replace earlier own values.
- **Output:** A normal object whose prototype remains exactly `Object.prototype`,
  whose dangerous-name keys are inert own properties, and whose raw text is
  protected only under the shape/body-mode contract.
- **Errors:** Existing expression errors/unresolved values retain current
  behavior. Non-string final type does not activate protection.

Ordering is per regular-object frame. Context property getters append labels to
an external log: a flat body-mode vector logs all dynamic-key getters before any
dynamic-type getter, then ordinary value getters. A nested vector applies the
same rule per frame; child events occur when that child value is transformed. An
object with own keys `"2"`, `"1"`, and `alpha` proves ECMAScript order
`"1"`, `"2"`, `alpha`. No internal trace hook is required.

With body mode off, the same getters MUST preserve existing per-entry
key-then-value order. Dangerous resolved keys still use safe own definitions in
both modes and do not affect expression/error order.

Authoritative vectors:

| Input/context/mode | Exact relevant output |
|---|---|
| `{type:"html",text:"<p>{{secret}}</p>",style:{height:"{{height}}"}}`; `{secret:"LEAK",height:40}`; on | `{type:"html",text:"<p>{{secret}}</p>",style:{height:40}}` |
| `{type:"{{kind}}","{{slot}}":"<p>{{secret}}</p>"}`; `{kind:"html",slot:"text",secret:"LEAK"}`; on | `{type:"html",text:"<p>{{secret}}</p>"}` |
| `{"{{typeKey}}":"{{kind}}",text:"{{secret}}"}`; `{typeKey:"type",kind:"html",secret:"LEAK"}`; on | `{type:"html",text:"{{secret}}"}` |
| `{type:"html","{{slot}}":"first",text:"second"}`; `{slot:"text"}`; on | `{type:"html",text:"second"}` |
| `{type:"label",text:"{{secret}}"}`; `{secret:"OK"}`; on | `{type:"label",text:"OK"}` |
| `{type:"html",text:"{{secret}}"}`; `{secret:"GENERIC"}`; off/omitted | `{type:"html",text:"GENERIC"}` |

Additional required vectors:

- A later resolved `type` changing `html` to `label` transforms text; reverse
  order retains it raw.
- A protected object-valued text entry retains the same reference.
- HTML shapes emitted by every conditional directive and `#each`, and nested in
  each listed body location, receive protection.
- An embedded body-tree action option `{type:"html",text:"{{secret}}"}` retains
  raw text immediately after body transformation. A production vector invokes
  `executeAction({type:"$set",options:{probe:{type:"html",text:"{{$jason.value}}"}}}, state, {value:"ACTION"})`;
  the resulting `state.local.probe.text` is `ACTION`, proving action-time generic
  transformation. A second `$set` vector carries own `__proto__`, `constructor`,
  and `prototype` options and proves `state.local` keeps `Object.prototype` while
  receiving inert own properties. `$cache.set` and `$global.set` receive
  equivalent coverage. `$session.set` separately proves (1) the stored session
  safely owns dangerous option keys while retaining `Object.prototype`, and (2)
  `state.sessions` safely owns reachable normalized domains `__proto__`,
  `constructor`, and `prototype` while retaining `Object.prototype`. A lookup
  rejection vector sets
  `state.sessions = Object.create({"api.example.com": inheritedSession})`, then
  requests `https://api.example.com`; inherited headers/body do not decorate the
  request. Null-prototype input options remain supported.
- Resolved `__proto__`, `constructor`, and `prototype` are inert enumerable own
  properties in body and off modes; the result prototype remains
  `Object.prototype`.
- Enumeration excludes inherited properties. Direct renderer vectors (without a
  transform first) prove only own exact string `type: "html"` enters component or
  background HTML paths. Inherited/missing/non-string/non-html and own
  `__proto__`/`constructor`/`prototype` types create no HTML iframe and do not
  throw. `executeAction()` receives the same type matrix and treats every
  non-own/non-string/non-callable/prototype-colliding type as unknown without
  invoking inherited handlers. Full transform-to-render vectors cover inherited
  text/url/css, inherited text plus own URL, inherited URL plus own text, and
  inherited CSS plus own text.
- A direct `executeAction()` vector proves its production options transform
  remains generic. An embedded action shape is raw immediately after body
  transformation; its later execution follows existing generic option templating.

### Behavior: Select and Compose an HTML Source

| Own text | Own URL | Result |
|---|---|---|
| non-empty string (including whitespace) | any | INLINE; text wins |
| empty/non-string/missing | non-empty string | URL |
| empty/non-string/missing | empty/non-string/missing | NONE |
| inherited-only text/url | any | ignore inherited fields |

CSS vectors (shown values are exact runtime strings):

| HTML | Own CSS | Exact `srcdoc` |
|---|---|---|
| `<p>x</p>` | absent/empty/null/undefined/non-string/inherited | `<p>x</p>` |
| `<p>x</p>` | one U+0020 space | `<style> </style><p>x</p>` |
| `<p>x</p>` | tab+newline | same tab+newline retained inside `<style>...</style>` |
| `<p>x</p>` | `</STYLE>` | `<style><\/style></style><p>x</p>` |
| `<p>x</p>` | `a</style>b</StYlE>c` | `<style>a<\/style>b<\/style>c</style><p>x</p>` |

A JavaScript assertion encodes one runtime U+005C with two source backslashes:

```javascript
expect(htmlSrcdoc("<p>x</p>", "</STYLE>"))
  .toBe("<style><\\/style></style><p>x</p>");
```

Invalid HTML is not parsed, sanitized, or rewritten before assignment.

### Behavior: Create and Maintain HTML Iframes

At `renderComponent()` return, the `.jasonette-html` wrapper remains detached
from the live document and owns its iframe child. The background path appends
`.jasonette-background-web` as a direct child of the renderer root. Both use
the same security policy and source exclusivity.

Security trace observer records only:

- `CREATE(kind)` when `document.createElement("iframe")` returns, where `kind` is
  assigned by the test call site as `component` or `background`;
- `SANDBOX(value)` for sandbox set/remove/replace operations;
- `SOURCE(name)` for `srcdoc` or `src` assignment;
- `APPEND` for every insertion of that iframe into any parent;
- `RETURN` when the component wrapper or background render call returns.

Pure computation, property reads, class/ARIA operations, and individual style
reads/writes are excluded. The required creation trace is exactly:

```text
CREATE(kind) -> SANDBOX("allow-scripts") -> SOURCE("srcdoc"|"src")
-> APPEND -> RETURN
```

For component mode, `RETURN` means `renderComponent()` returned its wrapper. For
background mode, it means `renderBodyBackground()` returned. Events are grouped
per created iframe. Each created iframe has one sandbox event: the required
initial set. No additional sandbox event occurs before return. `RETURN` belongs
only to a created-iframe trace; no-source calls create no per-iframe trace.
Endpoint assertions check exact sandbox state after initial render and after
`$render`; they do not claim continuous post-return observation.

### Behavior: Renderer Integration and `$render` Liveness

Use this body-template shape with initial data
`{kind:"html",secret:"LEAK",height:40,label:"first"}`:

```json
{
  "sections": [{
    "items": [
      {
        "type": "{{$jason.kind}}",
        "text": "<script>window.__html_boundary = \"{{$jason.secret}}\"</script>",
        "style": {"height": "{{$jason.height}}"}
      },
      {"type": "label", "text": "{{$jason.label}}"}
    ]
  }]
}
```

Initial exact DOM expectations:

- `.jasonette-html iframe` contains literal `{{$jason.secret}}` in `srcdoc`;
- `.jasonette-html` has `style.height === "40px"`;
- `.jasonette-label` has `textContent === "first"`;
- iframe sandbox is exact `allow-scripts`, inline iframe has no `src` attribute.

Invoke the actual action path:

```javascript
await executeAction({
  type: "$render",
  options: {
    data: {kind: "html", secret: "SECOND", height: 80, label: "second"}
  }
}, renderer.getState());
```

Post-action expectations:

- the queried iframe is a different DOM node from the initial iframe;
- `.jasonette-html` has `style.height === "80px"`;
- label text is `second`;
- the new iframe still contains literal `{{$jason.secret}}`, not `SECOND`.

`Jasonpedia/view/component/html/index.json` MUST be rendered through
`JasonetteRenderer`; its iframe `srcdoc` must contain both
`img{width: 100%;}` and `Nexus devices`. Synthetic script assertions inspect the
rendered iframe `srcdoc`, not fixture source text.

Authoritative background vectors (each snippet is placed in the named body slot
inside a complete `JasonDocument`):

| Entry path | Authored object and context | Expected source |
|---|---|---|
| static `body.background` | `{type:"html",text:"<p>static</p>",css:"p{color:red}"}` | inline exact `<style>p{color:red}</style><p>static</p>` |
| static `body.style.background` | `{type:"html",url:"https://example.com/bg.html"}` | URL exact authored URL, no `srcdoc` attribute |
| templated `head.templates.body.background` | `{type:"html",text:"<p>{{$jason.secret}}</p>",css:"p{color:{{$jason.color}}}"}` with `{secret:"LEAK",color:"red"}` | inline raw literal secret expression and transformed red CSS |
| templated `head.templates.body.style.background` | `{type:"html",url:"{{$jason.url}}"}` with `{url:"https://example.com/dynamic.html"}` | URL dynamic URL, no `srcdoc` attribute |
| either path | `{type:"html"}` | no iframe/per-iframe trace |

Background location selection examines own path segments only and then applies
nullish precedence:

| Own canonical `body.background` | Own `body.style` object with own `background` | Selected value |
|---|---|---|
| non-nullish (including false, empty, malformed, or HTML with no source) | any | canonical; never fall back |
| null or undefined/missing/inherited | present | legacy |
| null/undefined/missing/inherited | absent/inherited | none |

Direct vectors cover inherited canonical background with own legacy fallback,
inherited `style` with no canonical value, inherited legacy background inside an
own style object, and each inherited path combined with no fallback.

For a selected own exact `type: "html"` object, the complete component source
and CSS matrices apply independently to the background path. Canonical and
legacy paths each cover inline, URL, dual-source, non-string/empty sources,
repeated CSS escaping, inherited fields, prototype-colliding type values, and no
source. Rows that create an iframe assert exact sandbox, exclusive attributes,
class `.jasonette-background-web`, `aria-hidden="true"`, and source. No-source
rows assert iframe absence and an empty per-iframe trace.

## Key Decisions

- **Shape-based body-tree protection:** safer and simpler than maintaining a
  fragile list of component-bearing structural positions. Embedded action data
  in a body tree is intentionally protected; separate action transforms remain
  generic.
- **Safe own-property definition:** preserves ordinary-object compatibility while
  making dangerous resolved key names inert.
- **Both HTML iframe paths are sandboxed:** a document author controls both, so
  leaving backgrounds unsandboxed would bypass the boundary.
- **Scripts but no same-origin:** preserves legacy interactive fixtures while
  isolating host DOM/storage privileges.
- **Finite renderer-owned observation:** proves creation-through-return ordering
  and retained final state without claiming control over external DOM mutation.
- **Policy evidence, not browser enforcement:** jsdom proves emitted behavior;
  browser enforcement remains a platform assumption.

## Scope Boundaries

- **In scope:** template-engine option and safe output semantics; all body-tree
  call sites; component/background iframe sandbox/order/source exclusivity;
  focused and integration tests.
- **Out of scope:** HTML sanitization; CSP; Permission Policy; Referrer Policy;
  URL scheme/origin/redirect rules; cookies; referrer leakage; browser execution
  tests; native HTML renderers; agent bridges; additional sandbox capabilities.
- **Future:** real-browser tests may verify child script execution and denied host
  DOM/storage access. Any additional iframe capability requires explicit review.

## Success Criteria

- Every normative transform/source/CSS/dangerous-key/body-location vector passes.
- Initial and actual `$render` action paths satisfy the liveness/DOM oracle.
- Component inline, component URL, background inline, and background URL traces
  match the exact event alphabet/order and have exclusive source attributes.
- Component wrappers retain class `jasonette-html`, data type `html`, iframe
  style width `100%`/border `none`, and detached-at-return topology; backgrounds
  retain direct-root parentage, class, ARIA, and placement before foreground.
- Initial and replacement iframe endpoint sandbox states are exact after the
  actual `$render`; the old iframe object also retains its exact attribute after
  renderer disconnection.
- No-source and inherited-only-source cases emit no iframe; mixed inherited/own
  cases follow the own field.
- jsdom claims remain limited to emitted policy and data.
- Exact required commands:

```text
npm run test --workspace=@jasonette/template-engine -- transformer.test.ts
npm run test --workspace=@jasonette/web -- components.test.ts integration.test.ts actions-parity.test.ts renderer.test.ts
npm run typecheck --workspace=@jasonette/template-engine
npm run typecheck --workspace=@jasonette/web
npm run build --workspace=@jasonette/template-engine
npm run build --workspace=@jasonette/web
npm run test --workspace=@jasonette/template-engine
npm run test --workspace=@jasonette/web
```

Acceptance truth table for the final full Web suite:

| Local full Web suite | Isolated `cli.test.ts` | Exact implementation-SHA Web CI | Slice acceptance |
|---|---|---|---|
| pass | not needed | pass | pass |
| only CLI timeout; all other Web tests pass | pass | pass | pass with local timeout documented |
| any non-CLI failure | any | any | fail |
| CLI timeout | fail | any | fail |
| any | any | missing/fail | fail |

## Open Questions

### Resolved

- Protection is shape-based across the whole body tree.
- Dangerous resolved keys become inert own data properties.
- Both HTML component and background iframes are sandboxed.
- URL mode requires absence, not emptiness, of `srcdoc`.
- The strict event invariant ends at render-function return; exact endpoint state
  is checked after initial render and `$render` without continuous monitoring.

### Deferred

- Browser enforcement, URL/origin policy, CSP, permissions/referrers, and extra
  sandbox capabilities require separate specifications.
