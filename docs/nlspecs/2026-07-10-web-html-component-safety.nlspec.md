---
date: 2026-07-10
topic: Web HTML template and iframe safety boundary
source_spec: docs/specs/2026-07-10-web-html-component-safety-spec.md
status: reviewed
---

# Web HTML Template and Iframe Safety Boundary NLSpec

This NLSpec defines body-scoped raw-HTML preservation, safe resolved-key output,
and sandboxed Web HTML component/background iframes. Independent Foundry red and
green teams must be able to test and implement it without shared hidden context.

## Table of Contents

- [1. Why](#1-why)
- [2. What](#2-what)
- [3. How](#3-how)
- [4. Out of Scope](#4-out-of-scope)
- [5. Design Decision Rationale](#5-design-decision-rationale)
- [6. Definition of Done](#6-definition-of-done)

---

## 1. Why

### 1.1 Problem Statement

The Web renderer evaluates strings inside privileged `html.text`, can mutate an
output object's prototype through resolved `__proto__` keys, and creates both
HTML component and background iframes without a sandbox. It must preserve raw
HTML only during body-template transformation, produce safe own data properties,
and install an opaque script-capable sandbox before assigning any HTML iframe
source.

### 1.2 Design Principles

**Raw HTML is opaque in body mode.** A final shape of exact own
`type === "html"` retains resolved own `text` values without evaluation.

**Generic transforms remain generic.** The option defaults off. Only body
rendering opts in, including initial rendering and `$render`.

**Classification is deterministic.** All keys resolve once before any type value
or ordinary value transforms. Final type and insertion-order collisions are
therefore stable.

**Resolved keys are inert data.** Dangerous names become ordinary own data
properties and cannot mutate prototypes or become inherited component fields.

**Equivalent HTML paths receive equal privilege.** HTML component and HTML
background iframes both receive exact `allow-scripts` without same-origin.

**Policy exists before content.** Sandbox assignment is the first
security-observed iframe operation after creation; retained final state remains
exact through renderer disconnection or test completion.

**Evidence matches the test platform.** jsdom proves transformation and emitted
DOM policy, not browser sandbox enforcement.

### 1.3 Layering and Scope

The generic TypeScript template engine owns the opt-in option, resolved-key
ordering, classification, recursive transformation, and safe output properties.
The Web renderer enables the option for selected body templates. HTML component
and background renderers own source selection and sandbox/order/attribute
behavior. Tests cover each layer and the complete `$render` path.

---

## 2. What

### 2.1 Data Model

```text
RECORD RenderOptions:
    preserve_html_text : Boolean OPTIONAL = false
    -- TypeScript property name: preserveHtmlText
    -- Existing option fields remain unchanged.

RECORD ResolvedEntry:
    index : Integer
    authored_key : String
    resolved_key : String
    authored_value : Any
    transformed_type_value : Any OPTIONAL

ENUM HtmlSourceKind:
    INLINE
    URL
    NONE

RECORD HtmlSourceSelection:
    kind : HtmlSourceKind
    value : Any OPTIONAL

ENUM IframeTraceEventKind:
    CREATE
    SANDBOX
    SOURCE
    APPEND
    RETURN

CONSTANT HTML_TYPE = "html"
CONSTANT HTML_TEXT_KEY = "text"
CONSTANT HTML_SANDBOX = "allow-scripts"
```

### 2.2 Architecture

```text
initial render or $render
    -> renderSync(body_template, context, preserve_html_text = true)
        -> transform recursively
            -> resolve all object keys
            -> transform final type candidates
            -> protect raw text under final HTML shape
            -> define safe own output properties
    -> render body
        -> HTML component or HTML background
            -> own-field source selection
            -> sandboxed iframe creation
```

The mode is shape-based throughout the entire body tree: roots, headers,
footers, sections, layouts, layers, backgrounds, nested arrays, directive
results, and nested action/options/payload objects. `executeAction()` performs a
separate generic options/continuation transform with the option omitted, as do
direct standalone `transform()` calls. Safe own-property definition applies to
both modes and to `$set`, `$cache.set`, `$global.set`, and session-state sinks.

### 2.3 Vocabulary

- **Body mode:** `preserve_html_text === true`.
- **Resolved key:** an authored key after existing key interpolation.
- **Final resolved type:** the last insertion-ordered transformed value whose
  resolved key is `type`.
- **Protected raw text:** an original value whose resolved key is `text` under
  exact final resolved type string `html` in body mode.
- **Safe own property:** enumerable, writable, configurable data property that
  does not invoke legacy `__proto__` mutation behavior.
- **Own source field:** `type`, `text`, `url`, or `css` obtained only when
  `Object.hasOwn()` is true.
- **Opaque script sandbox:** exact attribute `sandbox="allow-scripts"`.
- **Renderer-owned observation window:** iframe creation through the containing
  component/background render function's return; endpoint state is separately
  checked after initial render and `$render`, without a continuous-monitor claim.
- **Security observer:** the finite iframe-event observer defined in section 3.4.

---

## 3. How

### 3.1 Enable and Propagate Body Mode

```text
FUNCTION render_selected_body(template, context) -> Body:
    options = RenderOptions(preserve_html_text = true)
    RETURN render_sync(template, context, options)
```

Both initial `renderDocument()` body-template selection and `$render` body
re-rendering use this function. Recursive calls for arrays, directives, and
nested objects pass the same `RenderOptions` unchanged.

`executeAction()` option and continuation normalization calls `transform()` with
no body-mode option. Direct standalone `transform()` calls do the same. Both
therefore retain existing generic interpolation and per-entry evaluation order.
Passing an unrelated `RenderOptions` object without `preserveHtmlText` also means
false. An embedded action shape may be raw immediately after body transformation;
when that action executes, its options undergo the existing second generic
transformation and may interpolate against the action-time context.

### 3.2 Transform a Body-Tree Object Safely

Directive objects retain existing selection behavior. Objects/arrays emitted by
`#if`, `#elseif`, `#else`, or `#each` recursively receive the same options.
Regular-object enumeration uses ECMAScript `Object.keys()` order: own enumerable
string keys only, with array-index keys numerically ordered before other strings.

```text
FUNCTION safe_define(result, key, value):
    Object.defineProperty(result, key, {
        value: value, enumerable: true, writable: true, configurable: true
    })

FUNCTION transform_regular_object(object, context, options) -> Object:
    result = new ordinary Object with prototype exactly Object.prototype

    IF options.preserve_html_text != true:
        -- Existing generic order: each key, then its value, in insertion order.
        FOR EACH own enumerable string authored_key IN object:
            resolved_key = existing_key_interpolation(authored_key, context, options)
            output = transform(object[authored_key], context, options)
            safe_define(result, String(resolved_key), output)
        RETURN result

    entries = []
    -- Body pass 1: resolve every own key exactly once.
    FOR EACH own enumerable string authored_key, authored_value, index IN object:
        resolved_key = existing_key_interpolation(authored_key, context, options)
        APPEND ResolvedEntry(index, authored_key, String(resolved_key), authored_value)
            TO entries

    -- Body pass 2: pre-transform every resolved type exactly once.
    FOR EACH entry IN entries:
        IF entry.resolved_key == "type":
            entry.transformed_type_value = transform(entry.authored_value, context, options)

    final_type = last transformed_type_value in entries OR UNDEFINED
    protect = final_type is String AND final_type == "html"

    -- Body pass 3: retain raw text or transform, then safely define.
    FOR EACH entry IN entries:
        IF entry.resolved_key == "type":
            output = entry.transformed_type_value
        ELSE IF protect AND entry.resolved_key == "text":
            output = entry.authored_value
        ELSE:
            output = transform(entry.authored_value, context, options)
        safe_define(result, entry.resolved_key, output)

    RETURN result
```

In-scope state handlers use the same descriptor-safe copy:

```text
FUNCTION safe_copy_own(target, source):
    FOR EACH key IN Object.keys(source):
        safe_define(target, key, source[key])

$set, $cache.set, and $global.set call safe_copy_own(destination, options)

FUNCTION store_session(state, normalized_domain, options):
    stored_session = new ordinary Object with prototype Object.prototype
    safe_copy_own(stored_session, options)
    safe_define(state.sessions, normalized_domain, stored_session)
    ASSERT Object.getPrototypeOf(stored_session) == Object.prototype
    ASSERT Object.getPrototypeOf(state.sessions) == Object.prototype

FUNCTION lookup_session(state, normalized_domain):
    IF Object.hasOwn(state.sessions, normalized_domain):
        RETURN state.sessions[normalized_domain]
    RETURN empty session
```

Both session levels receive separate vectors: dangerous option keys on the stored
session, and reachable normalized domains `__proto__`, `constructor`, and
`prototype` on the outer registry. For inherited-domain rejection, set
`state.sessions = Object.create({"api.example.com": inheritedSession})` and issue
a request to `https://api.example.com`; inherited headers/body MUST NOT decorate
the request. Null-prototype option inputs remain supported.

Author-controlled registries use own-callable lookup:

```text
FUNCTION own_callable(registry, type) -> Function OPTIONAL:
    IF type is not String OR Object.hasOwn(registry, type) == false:
        RETURN NONE
    candidate = registry[type]
    IF candidate is not Function:
        RETURN NONE
    RETURN candidate
```

Component missing/inherited/non-string type follows the existing label default;
own unknown/prototype-colliding string type returns the visible unknown-component
element. Action dispatch reads only own `type` and own `trigger`; inherited type
is missing. A missing/non-string type with an own string trigger calls
`lookup_named_action(state.actions, trigger)`. `$lambda` calls the same lookup for
`options.name`. Own named entries may be action objects or arrays; inherited
entries (including `toString`) are ignored. Own unknown/prototype-colliding action
type returns `undefined` without a continuation. Background rendering requires
own exact string `html`; all other types create no iframe. No case invokes
inherited members or throws.

```text
FUNCTION lookup_named_action(actions, name) -> ActionOrArray OPTIONAL:
    IF name is not String OR Object.hasOwn(actions, name) == false:
        RETURN NONE
    candidate = actions[name]
    IF candidate is not action object AND candidate is not action array:
        RETURN NONE
    RETURN candidate
```

Exact named-action vectors cover own/inherited `toString`, `constructor`, and
`__proto__` names for both trigger dispatch and `$lambda`; inherited `type` plus
own trigger falls through to that own trigger.

Ordering is scoped per regular-object frame. Context property getters append
labels to an external log. A flat body-mode vector logs all key getters before
type getters, then ordinary value getters. A nested vector applies the same rule
per frame. Off mode preserves existing per-entry key-then-value getter order. A
vector with own keys `"2"`, `"1"`, `alpha` proves Object.keys order
`"1"`, `"2"`, `alpha`. Dangerous resolved-key vectors combine this ordering
with prototype/error checks. No internal transform trace API is required.

Exact transform vectors:

| Input/context/mode | Exact relevant output |
|---|---|
| `{type:"html",text:"<p>{{secret}}</p>",style:{height:"{{height}}"}}`; `{secret:"LEAK",height:40}`; on | `{type:"html",text:"<p>{{secret}}</p>",style:{height:40}}` |
| `{type:"{{kind}}","{{slot}}":"<p>{{secret}}</p>"}`; `{kind:"html",slot:"text",secret:"LEAK"}`; on | `{type:"html",text:"<p>{{secret}}</p>"}` |
| `{"{{typeKey}}":"{{kind}}",text:"{{secret}}"}`; `{typeKey:"type",kind:"html",secret:"LEAK"}`; on | `{type:"html",text:"{{secret}}"}` |
| `{type:"html","{{slot}}":"first",text:"second"}`; `{slot:"text"}`; on | `{type:"html",text:"second"}` |
| `{type:"label",text:"{{secret}}"}`; `{secret:"OK"}`; on | `{type:"label",text:"OK"}` |
| `{type:"html",text:"{{secret}}"}`; `{secret:"GENERIC"}`; omitted/off | `{type:"html",text:"GENERIC"}` |

Required edge vectors:

- Later resolved type `html -> label`: text transforms.
- Later resolved type `label -> html`: text remains raw.
- Duplicate resolved text keys under final HTML type: each remains raw; last wins.
- Protected string output is strictly equal (`===`) to input.
- Protected object output is the same reference (`===`) as input.
- Missing, unresolved, and non-string final types do not activate protection.
- Shapes from `#if`, `#elseif`, `#else`, and `#each` are protected.
- Shapes nested under each body root/header/footer/section/layout/layer/background
  and nested array are protected.
- A body-tree nested action option `{type:"html",text:"{{secret}}"}` is protected;
  the same shape in a separate generic action-options transform interpolates.
- Resolved own `__proto__`, `constructor`, and `prototype` keys are inert
  enumerable properties in body and off modes;
  `Object.getPrototypeOf(result) === Object.prototype`.
- Safe-copy vectors pass those keys through `$set`, `$cache.set`, and
  `$global.set`; every destination retains `Object.prototype` and owns inert
  descriptors. Session vectors separately prove the inner stored object and outer
  domain registry, including inherited-domain lookup rejection.
- Direct vectors cover inherited, missing, non-string, non-html, `__proto__`,
  `constructor`, `prototype`, and `toString` type values. Components use the label
  default or own-string unknown element as specified; only own exact `html` enters
  component/background HTML paths. Actions invoke no inherited handler and return
  the specified trigger/undefined output. No case throws.
- Full transform-to-render vectors cover inherited text/url/css, inherited text
  plus own URL, inherited URL plus own text, and inherited CSS plus own text.
- Production generic vector:
  `await executeAction({type:"$set",options:{probe:{type:"html",text:"{{$jason.value}}"}}}, state, {value:"ACTION"})`
  produces `state.local.probe.text === "ACTION"`. Embedded action options are
  checked immediately after body transform and after their existing action-time
  generic transform.

Existing unresolved-expression behavior remains unchanged in the named existing
transformer tests. Invalid HTML receives no parser or sanitizer.

### 3.3 Select and Compose HTML Sources

Only own fields participate. Only non-empty string text/URL values are valid
sources; arbitrary JavaScript/JSON value coercion is not part of the boundary.

```text
FUNCTION own_value(component, key) -> Any:
    IF Object.hasOwn(component, key):
        RETURN component[key]
    RETURN UNDEFINED

FUNCTION select_source(component) -> HtmlSourceSelection:
    text = own_value(component, "text")
    url = own_value(component, "url")

    IF text is String AND text.length > 0:
        RETURN HtmlSourceSelection(INLINE, text)
    IF url is String AND url.length > 0:
        RETURN HtmlSourceSelection(URL, url)
    RETURN HtmlSourceSelection(NONE)
```

| Own text | Own URL | Result |
|---|---|---|
| non-empty string, including whitespace | any | INLINE; text wins |
| empty/non-string/missing | non-empty string | URL |
| empty/non-string/missing | empty/non-string/missing | NONE |
| inherited-only text/url | any | ignored |
| inherited text + own non-empty URL | own URL | URL |
| inherited URL + own non-empty text | any | INLINE |

```text
FUNCTION escape_style(css : String) -> String:
    REPLACE every case-insensitive "</style" with runtime code units:
        U+003C, U+005C, U+002F, "style"

FUNCTION compose_srcdoc(component, inline_text : String) -> String:
    css = own_value(component, "css")
    IF css is not String OR css.length == 0:
        RETURN inline_text
    RETURN "<style>" + escape_style(css) + "</style>" + inline_text
```

| HTML | Own CSS | Exact runtime `srcdoc` |
|---|---|---|
| `<p>x</p>` | absent/empty/null/undefined/non-string/inherited | `<p>x</p>` |
| `<p>x</p>` | one U+0020 | `<style> </style><p>x</p>` |
| `<p>x</p>` | tab+newline | identical tab+newline inside `<style>...</style>` |
| `<p>x</p>` | `</STYLE>` | `<style><\/style></style><p>x</p>` |
| `<p>x</p>` | `a</style>b</StYlE>c` | `<style>a<\/style>b<\/style>c</style><p>x</p>` |

The displayed backslash is runtime U+005C; JavaScript source uses `\\` to encode
it. Invalid HTML is assigned unchanged. URL security/network policy is outside
this jsdom slice; only source selection/attribute emission is asserted.

### 3.4 Create and Maintain HTML Iframes

The component registry MUST dispatch only an own registered renderer whose value
is a function; prototype-colliding type strings follow unknown-component behavior
without throwing. The background path enters HTML only for an own exact string
`type: "html"`.

The following helper is conceptual pseudocode; component and background paths
may implement it separately but MUST have identical observable policy/source
behavior. At `renderComponent()` return, the component wrapper is detached from
the live document, has class `jasonette-html` and `data-jasonette-type="html"`,
and owns its iframe child; the iframe keeps width `100%` and border `none`. A
background iframe is a direct child of the renderer root, has class
`jasonette-background-web` and `aria-hidden="true"`, and remains before
foreground sections.

```text
FUNCTION create_html_iframe(component) -> Iframe OPTIONAL:
    IF Object.hasOwn(component, "type") == false OR component.type != "html":
        RETURN NONE
    selection = select_source(component)
    IF selection.kind == NONE:
        RETURN NONE

    iframe = document.createElement("iframe")
    iframe.setAttribute("sandbox", "allow-scripts")

    IF selection.kind == INLINE:
        iframe.srcdoc = compose_srcdoc(component, selection.value)
        ASSERT iframe.hasAttribute("srcdoc") == true
        ASSERT iframe.hasAttribute("src") == false
    ELSE:
        iframe.src = selection.value
        ASSERT iframe.hasAttribute("src") == true
        ASSERT iframe.hasAttribute("srcdoc") == false

    RETURN iframe
```

The security observer records only:

- `CREATE(kind)` for iframe creation (`component` or `background`);
- `SANDBOX(value)` for sandbox set/remove/replace;
- `SOURCE(name)` for `srcdoc`/`src` assignment;
- `APPEND` for every insertion of the iframe into any parent;
- `RETURN` as observable completion: actual public `renderComponent()` return in
  direct calls; integrated wrapper `data-jasonette-type="html"` assignment after
  all iframe operations; actual runtime-wrapped background render return.

Pure computation, property reads, wrapper creation, class/ARIA operations, and
style reads/writes are excluded. Exact creation traces:

```text
CREATE(component) -> SANDBOX("allow-scripts") -> SOURCE("srcdoc"|"src")
-> APPEND -> RETURN

CREATE(background) -> SANDBOX("allow-scripts") -> SOURCE("srcdoc"|"src")
-> APPEND -> RETURN
```

Direct component tests use actual public function return. Integrated component
flows use the data-type completion marker and continue observing through the
containing public render/action return to prove no later iframe operation occurs.
Backgrounds use the runtime-wrapped `renderBodyBackground()` return. Events are
grouped per iframe. Each iframe records one initial sandbox event and no
additional event before its completion boundary. Endpoint checks
after initial render and `$render` assert exact sandbox state; the disconnected
old iframe object also retains its attribute. This is not a continuous
post-return mutation claim. No-source calls emit no per-iframe trace.

Inline mode has no `src` attribute. URL mode has no `srcdoc` attribute. Every
iframe has exact sandbox value `allow-scripts`, with no other token.

### 3.5 Integrate Initial Rendering and Actual `$render`

Use initial data `{kind:"html",secret:"LEAK",height:40,label:"first"}` and this
body template:

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

After `renderer.renderDocument(document)`:

- `.jasonette-html iframe` is present;
- iframe `srcdoc` contains exact
  `<script>window.__html_boundary = "{{$jason.secret}}"</script>`;
- `.jasonette-html.style.height === "40px"`;
- `.jasonette-label.textContent === "first"`;
- iframe sandbox is exact `allow-scripts` and it has no `src` attribute.

Then invoke the actual action path:

```javascript
await executeAction({
  type: "$render",
  options: {
    data: {kind: "html", secret: "SECOND", height: 80, label: "second"}
  }
}, renderer.getState());
```

After action completion:

- the current iframe is a different node from the initial iframe;
- both the disconnected initial iframe object and current iframe have exact
  sandbox endpoint value `allow-scripts`;
- `.jasonette-html.style.height === "80px"`;
- label text is `second`;
- the new iframe still contains literal `{{$jason.secret}}`, not `SECOND`.

Render `Jasonpedia/view/component/html/index.json` through
`JasonetteRenderer`. Its iframe `srcdoc` contains `img{width: 100%;}` and
`Nexus devices`; source-file grep is not evidence.

Background vectors place each authored object in the named body slot inside a
complete `JasonDocument` rendered by `JasonetteRenderer`:

| Entry path | Authored object and context | Expected source |
|---|---|---|
| static `body.background` | `{type:"html",text:"<p>static</p>",css:"p{color:red}"}` | exact inline `<style>p{color:red}</style><p>static</p>` |
| static `body.style.background` | `{type:"html",url:"https://example.com/bg.html"}` | exact URL and absent `srcdoc` attribute |
| templated `head.templates.body.background` | `{type:"html",text:"<p>{{$jason.secret}}</p>",css:"p{color:{{$jason.color}}}"}` with `{secret:"LEAK",color:"red"}` | literal secret expression plus transformed red CSS |
| templated `head.templates.body.style.background` | `{type:"html",url:"{{$jason.url}}"}` with `{url:"https://example.com/dynamic.html"}` | exact dynamic URL and absent `srcdoc` attribute |
| either static/templated path | `{type:"html"}` | no iframe/per-iframe trace |

Location selection checks own path segments, then nullish precedence:

| Own `body.background` | Own `body.style` object with own `background` | Selected |
|---|---|---|
| non-nullish, including false/malformed/no-source | any | canonical; no fallback |
| null/undefined/missing/inherited | present | legacy |
| null/undefined/missing/inherited | absent/inherited | none |

Direct vectors cover inherited canonical with own legacy fallback, inherited
`style`, inherited legacy background inside own style, and each inherited path
without fallback. The full component type/source/CSS matrix
is repeated independently through canonical and legacy background paths,
including dual source, non-string/empty source, repeated CSS escape, inherited
fields, prototype-colliding types, and no source. Created rows assert class,
ARIA, exact sandbox/source/trace; no-source rows assert iframe/trace absence.

### 3.6 Enforce Evidence and Verification Boundaries

Required jsdom evidence:

- transform outputs, strict equality/reference identity, own descriptors, and
  prototype identity;
- exact source strings, source-attribute absence/presence, sandbox tokens, finite
  operation traces, wrapper class/data type, iframe width/border, background
  class/ARIA, and background-before-foreground placement;
- initial/$render DOM liveness and rendered Jasonpedia `srcdoc` contents.

Prohibited claim: these tests do not prove child script execution, opaque-origin
enforcement, host DOM/storage denial, browser navigation, or network isolation.
Those remain browser-platform assumptions.

Exact required commands:

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

Final full-Web acceptance truth table:

| Local full Web | Isolated `cli.test.ts` | Exact implementation-SHA Web CI | Acceptance |
|---|---|---|---|
| pass | not needed | pass | pass |
| only CLI timeout; all other tests pass | pass | pass | pass with timeout documented |
| any non-CLI failure | any | any | fail |
| CLI timeout | fail | any | fail |
| any | any | missing/fail | fail |

### 3.7 Integration Smoke Test

```text
FUNCTION integration_smoke_test():
    renderer = create_renderer()
    document = document_with_template_from_section_3_5(
        data = {kind:"html", secret:"LEAK", height:40, label:"first"}
    )

    renderer.renderDocument(document)
    first_iframe = query(".jasonette-html iframe")
    ASSERT first_iframe exists
    ASSERT first_iframe.srcdoc contains literal "{{$jason.secret}}"
    ASSERT query(".jasonette-html").style.height == "40px"
    ASSERT query(".jasonette-label").textContent == "first"
    ASSERT first_iframe.getAttribute("sandbox") == "allow-scripts"
    ASSERT first_iframe.hasAttribute("src") == false

    await executeAction(
        {type:"$render", options:{data:{
            kind:"html", secret:"SECOND", height:80, label:"second"
        }}},
        renderer.getState()
    )

    second_iframe = query(".jasonette-html iframe")
    ASSERT second_iframe is not first_iframe
    ASSERT query(".jasonette-html").style.height == "80px"
    ASSERT query(".jasonette-label").textContent == "second"
    ASSERT second_iframe.srcdoc contains literal "{{$jason.secret}}"
    ASSERT second_iframe.srcdoc does not contain "SECOND"

    generic = transform(
        {type:"html", text:"{{secret}}"},
        {secret:"GENERIC"}
        -- Omit RenderOptions to prove default false.
    )
    ASSERT generic.text == "GENERIC"

    await executeAction(
        {type:"$set", options:{
            probe:{type:"html", text:"{{$jason.value}}"}
        }},
        renderer.getState(),
        {value:"ACTION"}
    )
    ASSERT renderer.getState().local.probe.text == "ACTION"

    ASSERT every observed component/background iframe trace matches section 3.4
```

---

## 4. Out of Scope

- **Browser sandbox enforcement.** Future Playwright/Vitest-browser tests may
  verify child execution and denied host DOM/storage access.
- **HTML sanitization and CSP.** Authored raw HTML remains unchanged.
- **URL/origin/network security.** Scheme, DNS, origin, redirect, cookies,
  referrer leakage, and network isolation require separate work.
- **Iframe policies beyond sandbox.** Permission Policy and Referrer Policy remain
  unchanged. Forms, popups, downloads, top navigation, and additional sandbox
  tokens require explicit review.
- **Native HTML and agent bridges.** iOS/Android renderers and agent APIs are not
  modified.

---

## 5. Design Decision Rationale

**Why shape-based body protection?** It avoids fragile structural-position lists
and protects semantic HTML anywhere in a transformed body. Embedded action data
inside that body is intentionally protected; separate action transforms remain
generic.

**Why define properties rather than assign?** Plain `result[key] = value` invokes
legacy `__proto__` behavior. Explicit own data properties preserve ordinary
object compatibility while making dangerous key names inert.

**Why sandbox backgrounds too?** The same author controls component and
background HTML. Leaving either path unsandboxed bypasses the host boundary.

**Why allow scripts but not same-origin?** Bundled fixtures need scripts; an
opaque origin reduces host privilege. Additional tokens are not required.

**Why a finite event observer?** It proves renderer-controlled creation order;
separate endpoint assertions avoid claiming continuous post-return monitoring.

**Why no real-browser claim?** jsdom is an attribute/data oracle, not a browser
security-enforcement oracle.

---

## 6. Definition of Done

### 6.1 Data Model (mirrors 2.1)

- [ ] `RenderOptions.preserveHtmlText` exists and omission is effectively false.
- [ ] Source selection and iframe-event values match the normative enums in
      black-box tests; no new public runtime type is required unless useful.
- [ ] Constants use exact values `html`, `text`, and `allow-scripts`.

### 6.2 Architecture (mirrors 2.2)

- [ ] Initial render and `$render` follow the body-mode pipeline through safe
      transform and sandboxed component/background iframe creation.
- [ ] Body roots, headers, footers, sections, layouts, layers, backgrounds,
      arrays, directives, and nested action/options/payload objects inherit mode.
- [ ] `executeAction()` option/continuation transforms and direct standalone
      transforms keep omitted/default-false mode and generic ordering.
- [ ] Safe own-property definition applies in both modes, `$set`, `$cache.set`,
      `$global.set`, both session storage levels, and own-only session lookup.
- [ ] Component/action handler registries dispatch only own registered functions;
      trigger and `$lambda` named-action lookups accept only own action entries.
- [ ] Exact own/inherited prototype-name vectors satisfy label/unknown/trigger/
      undefined outcomes without invoking inherited members.

### 6.3 Vocabulary (mirrors 2.3)

- [ ] Classification uses final resolved own type and protected resolved own text.
- [ ] Output fields are safe own data properties; iframe source fields are read
      only when own.
- [ ] Sandbox value and renderer-owned observation window match the normative
      definitions.

### 6.4 Body Mode (mirrors 3.1)

- [ ] Initial body-template rendering explicitly enables body mode.
- [ ] Actual `$render` re-rendering explicitly enables body mode.
- [ ] Arrays, nested objects, and all conditional/each directive recursion carry
      the same option.
- [ ] The exact section 3.2 `executeAction($set, state, {value:"ACTION"})`
      production vector produces `state.local.probe.text === "ACTION"`; direct
      standalone and unrelated-option transforms also prove generic behavior.
- [ ] An embedded body action option is raw immediately after body transform and
      follows existing generic interpolation when that action executes.

### 6.5 Safe Object Transformation (mirrors 3.2)

- [ ] Every exact transform vector in section 3.2 passes.
- [ ] Protected strings satisfy strict equality; protected objects retain strict
      reference identity.
- [ ] Observable getter logs prove per-frame all-keys-first body ordering and
      existing per-entry off-mode ordering for flat/nested vectors; numeric keys
      prove ECMAScript order `"1"`, `"2"`, `alpha`; each expression evaluates once.
- [ ] Later type collisions activate/deactivate protection according to final
      type; duplicate text collisions remain raw and use last-write-wins.
- [ ] Missing, unresolved, and non-string type values do not activate protection.
- [ ] `#if`, `#elseif`, `#else`, `#each`, arrays, and every listed body location
      receive protection.
- [ ] Embedded body action HTML shapes remain raw while separate generic action
      transforms interpolate.
- [ ] `__proto__`, `constructor`, and `prototype` become inert enumerable,
      writable, configurable own data properties without prototype mutation in
      both modes, while preserving their applicable getter/error order.
- [ ] End-to-end `$set`, `$cache.set`, and `$global.set` vectors retain destination
      `Object.prototype` and inert own descriptors.
- [ ] Two-level session vectors prove stored-session dangerous option descriptors,
      reachable outer domains `__proto__`/`constructor`/`prototype`, both
      prototypes, null-prototype input, and the reachable inherited
      `api.example.com` request-decoration rejection.
- [ ] Enumeration uses own enumerable string keys only.
- [ ] Direct inherited/missing/non-string/non-html/prototype-colliding component,
      background, and action type vectors follow exact label/unknown/trigger/
      undefined outcomes, invoke no inherited handler, and do not throw.
- [ ] Full transform-to-render inherited text/url/css and mixed inherited/own
      vectors obey own-field classification and source selection.
- [ ] Existing unresolved-expression behavior remains unchanged.

### 6.6 Source Selection and Composition (mirrors 3.3)

- [ ] Every string-only source-selection row passes, including dual source,
      whitespace, empty/non-string, inherited-only/mixed-own, and no source.
- [ ] Non-string text/URL values are ignored rather than coerced.
- [ ] Every CSS vector passes with exact runtime equality, including arbitrary
      non-empty whitespace retained code-unit-for-code-unit.
- [ ] Mixed-case/repeated closing-style replacements contain runtime U+005C.
- [ ] Invalid HTML is assigned without parsing/sanitizing/rewriting.
- [ ] Source selection and emitted attributes match the exact string-domain
      vectors; arbitrary coercion is not claimed.

### 6.7 Iframe Creation and Lifetime (mirrors 3.4)

- [ ] Direct component traces use actual public return; integrated component
      traces use the data-type completion marker and prove no later iframe event
      through public render/action return. Inline/URL order remains exact.
- [ ] Background inline and URL traces match the exact observer alphabet/order.
- [ ] Sandbox is each iframe's first security-observed operation, precedes every
      parent insertion/source event, and is exact `allow-scripts`.
- [ ] Each created iframe has one sandbox event before return; endpoint checks
      after initial render and `$render` find exact sandbox on old/new objects
      without claiming continuous monitoring.
- [ ] Inline has `srcdoc` and no `src`; URL has `src` and no `srcdoc`.
- [ ] No-source and inherited-only-source cases create no iframe/per-iframe trace;
      mixed inherited/own cases follow their own field.
- [ ] Component wrapper is detached at `renderComponent()` return, owns the
      iframe child, and has exact class/data type/iframe width/border.
- [ ] Background iframe is a direct renderer-root child with exact class/ARIA and
      remains before foreground content.

### 6.8 Renderer Integration (mirrors 3.5)

- [ ] Initial DOM matches every section 3.5 selector/value expectation.
- [ ] Actual `executeAction($render, renderer.getState())` creates a different
      iframe node, changes height `40px -> 80px`, and label `first -> second`.
- [ ] The new iframe retains literal raw script braces and excludes `SECOND`;
      both old and new iframe objects have exact sandbox endpoint state.
- [ ] Rendered Jasonpedia iframe `srcdoc` contains `img{width: 100%;}` and
      `Nexus devices`.
- [ ] Own-path canonical/legacy background nullish precedence—including inherited
      canonical/style/legacy segments—and independent full type/source/CSS matrices
      satisfy exact sandbox/source/ARIA/trace or no-source outcomes.
- [ ] Rendered component/background HTML retains authored CSS/script contents and
      ordinary sibling interpolation.

### 6.9 Evidence and Verification (mirrors 3.6)

- [ ] jsdom evidence covers transform output, equality/identity, descriptors,
      prototypes, strings, exclusive attributes, sandbox tokens, and traces.
- [ ] No report claims jsdom proved script execution, origin enforcement, host
      access denial, browser navigation, or network isolation.
- [ ] The first seven exact commands in section 3.6 pass. The eighth (full Web)
      passes directly or satisfies the exact documented CLI-timeout substitute.
- [ ] Final full-Web evidence satisfies one passing row of the acceptance truth
      table; a CLI timeout requires isolated `cli.test.ts` pass and exact
      implementation-SHA Web CI pass.

### 6.10 Integration Smoke (mirrors 3.7)

- [ ] The integration smoke test runs the actual initial and `$render` paths,
      proves DOM liveness through node/style/label changes, preserves raw text,
      proves omitted-option default behavior, and validates all observed iframe
      traces.
