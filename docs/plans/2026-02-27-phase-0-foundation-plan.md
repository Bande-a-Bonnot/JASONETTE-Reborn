---
title: "Phase 0: Foundation"
type: feat
date: 2026-02-27
status: completed
parent: docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md
milestone: 1
branch: feat/phase-0-foundation
deepened: 2026-02-27
---

# Phase 0: Foundation

## Enhancement Summary

**Deepened on:** 2026-02-27
**Agents used:** Architecture Strategist, Code Simplicity Reviewer, Agent-Native Reviewer, Agent-Native Architecture Skill, Security Sentinel (12 findings), Pattern Recognition Specialist (18 findings), Best Practices Researcher (OSS scaffolding)

### Critical Corrections

1. **`components` key missing from vocabulary** — Jasonpedia uses `components` (48 files, 116 occurrences) as the child-element key inside layouts, distinct from `items` in sections. The spec and schema must define both.
2. **`$script.eval` does not exist** — The actual action is `$script.include` (loads external/inline JS). `$script.eval` was invented; corrected throughout.
3. **`{{#each}}` syntax is JSON object-key pattern** — There is no closing `{{/each}}` tag. The `{{#each expr}}` string is the key of a JSON object whose value is the template. Same for `{{#if}}`.
4. **`$addressbook` is `$util.addressbook`** — Jasonpedia uses `$util.addressbook`, not a top-level namespace.
5. **`sections` can be a template-object, not just an array** — e.g., `"sections": {"{{#each $jason}}": {...}}`.
6. **`$render` has undocumented options** — `options.template` (select named template) and `options.data` (override render data) are heavily used.

### Critical Security Findings

1. **SSRF blocklist strategy is naive** — Must use scheme allowlist (HTTPS only) + post-DNS-resolution private-address blocking, not a string-based IP blocklist.
2. **`$script.include` collapses JSEP sandbox** — Functions loaded via `$script.include` must NOT be callable from JSEP template expressions. Two distinct execution contexts required.
3. **Template expression grammar must be formally defined** — Phase 0 spec must codify what is/isn't a valid v2.0 expression before Phase 0.5 starts.
4. **Trust model incomplete** — Mixin cross-origin injection and `$params` as untrusted input are unaddressed.

### Scope Simplifications Applied

1. Conformance test fixtures: input JSON only in Phase 0; expected output deferred to Milestone 2 (template engine builds the ground truth)
2. Action catalogue: full detail for Tier 1; stub entries for Tier 2/3 (name + one-line description)
3. JSON Schema: structural validation focus; `description`/`examples` polish deferred to Milestone 8
4. Task 0.7 (v1 compat) merged into tasks 0.2 and 0.4

---

## Goal

Establish project infrastructure before writing any app code. Formalize the `$jason` protocol as a versioned specification with JSON Schema validation, set up CI/CD, and create the project scaffolding.

## Deliverables

1. **`$jason` Schema Spec v2.0** (`spec/jason-v2.0.md`) — Formal specification extracted from Jasonpedia examples + original iOS/Android/Web source analysis. Includes v1-compat breaking changes and security model.
2. **JSON Schema file** (`spec/schema/jason.schema.json`) — Machine-readable schema (Draft 2020-12) for editor autocompletion and validation
3. **Action catalogue** (`spec/actions.json` + `spec/actions.md`) — Structured JSON + human-readable catalogue with tier assignments and I/O shapes
4. **Project scaffolding** — Directory structure, CONTRIBUTING.md, CODE_OF_CONDUCT.md, GOVERNANCE.md, SECURITY.md, README.md, package.json with npm workspaces
5. **CI/CD** — GitHub Actions for JSON Schema validation + markdown linting + change detection
6. **Conformance test skeleton** (`spec/conformance/`) — Input JSON fixtures + test case manifest for static Jasonpedia examples

## Architectural Decisions for Phase 0

### AD-1: Nested Git Repos — Remove Completely

**Decision: Physically remove nested `.git` directories; treat forked repos as plain directories in the monorepo.** The original repos are archived references, not actively tracked upstream.

**Action (two-step):**
1. `rm -rf JASONETTE-iOS/.git JASONETTE-Android/.git Jasonette-Web/.git Jasonette-Blog/.git Jasonette-documentation/.git Jasonpedia/.git` — physically delete the nested git databases
2. Add these paths to `.gitignore` to prevent re-creation: `*/.git`
3. `git add -A` the now-trackable contents and commit

### AD-2: Conformance Test Output Definition

**Decision: Input-only fixtures in Phase 0; expected output deferred to Milestone 2.**

A Phase 0 conformance fixture is:
- **Input:** A standalone `$jason` JSON document with `head.templates` + `head.data`
- **Metadata:** YAML manifest with `id`, `description`, `tier`, `spec_section`, `tags`
- **Expected output:** Deferred to Milestone 2, where the template engine itself produces the ground truth from the inputs. Writing expected output by hand without a reference implementation risks encoding incorrect assumptions.
- **NOT included:** Action execution, network calls, lifecycle hooks.

**Scope:** Only Jasonpedia files with `head.templates` + `head.data` (pure template examples). Eligible files: `template/each.json`, `template/if.json`, `template/inline.json`, `template/index.json`, and `webcontainer/agent/index.json`. Action-driven files deferred to Milestone 2.

### AD-3: Schema vs Jasonpedia v1.x Compatibility

**Decision: Schema validates v2.0 structures. v1.x-only features documented inline in the spec with migration paths.**

CI runs schema validation against Jasonpedia with a **machine-readable** exclusion list (`spec/schema/v1-exclusions.json`) for known v1.x-only files. Format:

```json
[
  {"file": "template/jsfunction.json", "reason": "Multi-statement JS expressions (v1.x only)", "migration": "Use $script.include for multi-statement logic"},
  {"file": "view/layer/dynamic.json", "reason": "Multi-statement JS in $set options", "migration": "Extract to $script.include"}
]
```

The success criterion: "all in-scope Jasonpedia files validate; out-of-scope files are explicitly listed in the exclusion JSON."

### AD-4: Template Expressions in String Values

**Decision: Schema treats all string properties as `type: string` with no format constraint.** Template expression validity is a template engine concern.

**Exception:** URL-bearing fields (`url` in `$href`, `$network.request`, `image`, `background`, `@` mixin) use `format: "uri"` as a non-validating hint. Action `type` and `$href.view` fields use `enum` constraints for known values.

### AD-5: Property Naming Convention

**Decision: `snake_case` for all Jasonette-specific properties in v2.0.** The only affected property in the Jasonpedia corpus is `dataType`/`data_type`. The schema accepts both for this specific property only. No blanket `oneOf`/`anyOf` for a broad migration — the scope is narrower than originally stated.

### AD-6: Missing Actions — Tier Assignments (Corrected)

| Action | Tier | Rationale |
|---|---|---|
| `$back` | 1 | Required for navigation stack; used universally |
| `$close` | 1 | Required for modal dismissal |
| `$flush` | 1 | Used in 9 Jasonpedia files; alias for per-URL cache reset |
| `$return.success` / `$return.error` | 1 | Explicit entries in catalogue (source-documented, not in Jasonpedia examples) |
| `$media.play` | 2 | Video playback; appears in Jasonpedia action index |
| `$network.upload` | 2 | Distinct from `$network.request`; used in imagejason demo |
| `$util.addressbook` | 2 | Contact access (corrected namespace: `$util.*`, not standalone) |
| `$snapshot` | 2 | Screenshot capture; not needed for core rendering |
| `$default` | 2 | Webcontainer-only; depends on $agent |
| `$widget.banner` | 3 | iOS-only widget notification; may be alias for `$util.banner` |
| `$notification.*` | 2 | Distinct from $push; local notification support |
| `$script.include` | 3 | Load external/inline JS (corrected from `$script.eval`) |

### AD-7: JSON Schema `$id`

**Decision:** `https://schema.jasonette.dev/v2/jason.schema.json` — using a dedicated schema subdomain that can be pointed at GitHub Pages.

### AD-8: Template Expression Grammar Boundary (NEW)

**Decision: Formal expression grammar defined in spec before Phase 0.5 starts.**

Valid v2.0 template expressions:
- Identifiers, member access (dot and bracket), literals
- Binary operators (`+`, `-`, `*`, `/`, `%`, `==`, `!=`, `===`, `!==`, `<`, `>`, `<=`, `>=`, `&&`, `||`)
- Unary operators (`!`, `-`, `+`)
- Ternary operator (`? :`)
- Function calls from allowlist only (`Math.*`, `JSON.stringify`, `JSON.parse`, `parseInt`, `parseFloat`, `String`, `Number`, `encodeURIComponent`, `decodeURIComponent`)
- `$root`, `$index`, `$jason`, `$get`, `$params`, `$env`

**NOT valid** (breaking change from v1.x): `var`, `let`, `const`, `function`, `return`, `for`, `while`, `if` (statement form), `new`, `typeof`, `void`, `delete`, comma operator, assignment operators (`=`, `+=`, etc.).

**Security rule for `MemberExpression`:** Property blocklist (`__proto__`, `constructor`, `prototype`) must be checked for BOTH computed (`obj["key"]`) and non-computed (`obj.key`) access paths.

### AD-9: Execution Context Boundary (NEW)

**Decision: Two distinct execution contexts, with no cross-contamination.**

1. **JSEP expression context** — Pure template expressions. Has access to: `$jason`, `$get`, `$params`, `$root`, `$index`, function allowlist. Does NOT have access to functions loaded by `$script.include`.
2. **Script engine context** (JavaScriptCore / QuickJS / V8 isolate) — `$script.*` actions only. Has access to: loaded libraries, `$get`/`$set` state, `$cache` contents. Sandboxed from native APIs.

Jasonpedia examples that call `he.decode()` or `_.map()` in template expressions are v1.x patterns that require reclassification to the script engine context.

### AD-10: URL Validation Policy (NEW)

**Decision: Allowlist-based URL validation for all network-facing operations.**

Applies to: `$network.request`, `@` mixin operator, `$script.include`, `$href` with external URLs.

1. **Scheme allowlist:** `https:` only by default. `http:` opt-in via `jasonette.config.json` `allow_http: true` (requires `debug: true`).
2. **Post-DNS-resolution blocking:** After DNS resolution, block requests to any IP in: RFC1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), loopback (`127.0.0.0/8`, `::1`), link-local (`169.254.0.0/16`, `fe80::/10`), documentation ranges, carrier-grade NAT (`100.64.0.0/10`), `0.0.0.0`.
3. **Redirect policy:** Follow at most 1 redirect. Redirect target must also pass URL validation.
4. **Scheme blocklist:** `file://`, `javascript:`, `data:` always blocked.

### AD-11: Mixin Origin Policy (NEW)

**Decision: Same-origin by default for remote mixins.**

- Form A (local `$document` reference): always allowed
- Form B/C (remote URL): restricted to same origin as root document by default
- Cross-origin mixins require explicit `allowed_mixin_origins` in `jasonette.config.json`
- Recursion depth limit: 5 (unchanged)
- Mixin size limit: 1MB (unchanged)

---

## Tasks

### 0.1 — Project Structure & Scaffolding

**Files to create/modify:**

- [ ] `package.json` — Root npm workspace config with scoped workspaces:
  ```json
  {
    "name": "jasonette-reborn",
    "private": true,
    "workspaces": ["Jasonette-Web", "packages/*"],
    "engines": { "node": ">=20" },
    "scripts": {
      "test": "npm run test --workspaces --if-present",
      "lint": "npm run lint --workspaces --if-present",
      "conformance": "npm run test -w packages/conformance",
      "spec:validate": "npx ajv validate -s spec/schema/jason.schema.json -d 'Jasonpedia/**/*.json' --spec=draft2020"
    }
  }
  ```
- [ ] `.gitignore` — Add `*/.git` pattern + verify Node/Swift/Kotlin/Rust coverage
- [ ] `CONTRIBUTING.md` — Contribution guidelines with sections: ways to contribute, dev setup per platform, commit conventions (Conventional Commits with platform scopes: `feat(ios):`, `feat(web):`, `feat(spec):`), PR process, issue reporting (bug vs spec-ambiguity vs feature-request)
- [ ] `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1
- [ ] `GOVERNANCE.md` — BDFL model with written succession clause (60-day inactivity threshold), decision-making thresholds, path to maintainership
- [ ] `SECURITY.md` — Responsible disclosure process
- [ ] `README.md` — Project vision, current status, link to spec, link to roadmap plan
- [ ] `.github/CODEOWNERS` — All paths → lead maintainer, with `packages/spec/` requiring explicit approval
- [ ] `.github/pull_request_template.md` — PR template with: what/why, platform(s) affected checklist, how tested, spec conformance impact field, 3-item checklist
- [ ] `.github/ISSUE_TEMPLATE/bug_report.md` — Platform-specific bug template
- [ ] `.github/ISSUE_TEMPLATE/spec_ambiguity.md` — Protocol edge case template
- [ ] `.github/ISSUE_TEMPLATE/feature_request.md` — Feature request template
- [ ] `.markdownlint-cli2.jsonc` — Markdown lint config (disable MD013, allow inline HTML, sibling-only duplicate headings)
- [ ] Verify `spec/`, `spec/schema/`, `spec/conformance/`, `packages/`, `todos/` directories exist
- [ ] Remove nested `.git` directories from forked repos (per AD-1): `rm -rf` then `git add -A`

### 0.2 — Formalize the `$jason` Protocol Spec

**Output file:** `spec/jason-v2.0.md`

Extract from Jasonpedia examples + iOS/Android/Web source code + existing `Jasonette-documentation/docs/`:

**Document structure:**

- [ ] `$jason.head` — ALL properties: `title`, `description`, `icon`, `offline`, `styles`, `actions`, `templates`, `data`, `agents`
- [ ] `$jason.body` — `header`, `footer`, `sections`, `items`, `layers`, `background`, `style`
- [ ] Header structure: title, style, menu (left/right buttons), search bar, `shy` behavior
- [ ] Footer structure: tabs (items with badge, url, action), input, style
- [ ] Sections: items array, header per section. **Note: `sections` can also be a template-object** (`{"{{#each $jason}}": {...}}`) not just an array.
- [ ] Layers: absolute-positioned components with `name` attribute for dynamic targeting

**Components (with all properties and style options):**

- [ ] `label` — text, style (font, size, color, padding, corner_radius, etc.), action, href
- [ ] `image` — url, style (width, height, corner_radius, color), action, href
- [ ] `button` — text, url, style, action, href
- [ ] `textfield` — name, placeholder, value, style, action (for submit/return key)
- [ ] `textarea` — name, placeholder, value, style
- [ ] `html` — text (HTML content), style, action. **Security note: renders raw HTML. Template expressions should not be evaluated inside `text` field values. Document as privileged component.**
- [ ] `map` — region, pins, style
- [ ] `slider` — name, value, action
- [ ] `switch` — name, value, action
- [ ] `space` — style (height)
- [ ] **All components accept optional `href` property** (navigation on tap) — distinct from `$href` action

**Layouts:**

- [ ] `vertical` — **`components`** array (NOT `items`), style (spacing, padding)
- [ ] `horizontal` — **`components`** array, style (spacing, padding)
- [ ] Nesting rules (layouts within layouts within items)
- [ ] **`components` vs `items` distinction:** `items` = direct children of a section (full-height rows); `components` = children of a layout element within an item

**Template engine syntax (v2.0 scope per D3):**

- [ ] Variable binding: `{{$jason.name}}`, `{{name}}`
- [ ] Array iteration: **`{{#each items}}` as a JSON object key** — the key is the each expression, the value is the item template. No closing `{{/each}}` tag (this is JSON-structural, not Handlebars-string).
- [ ] Conditionals: **`{{#if condition}}` as a JSON object key** — same JSON-structural pattern as `{{#each}}`. `{{#elseif}}` and `{{#else}}` are sibling keys.
- [ ] JavaScript expressions (JSEP-parseable only per AD-8): member access, binary/unary/ternary operators, function calls from allowlist
- [ ] **Formal expression grammar** (per AD-8): enumerate allowed operators and functions; explicitly exclude statements
- [ ] `$root` for parent context access in nested loops
- [ ] `$index` for loop iteration index
- [ ] **Breaking change from v1.x:** Multi-statement expressions (`var`, `function`, `return`) are NOT supported. Use `$script.include` (Tier 3).

**Mixin system (three distinct forms):**

- [ ] Form A: `"@": "$document.key"` — local document reference (always allowed)
- [ ] Form B: `"@": "https://..."` — remote full-document inclusion (replaces containing object). **Subject to mixin origin policy (AD-11).**
- [ ] Form C: `"@": "key@https://..."` — remote JSON with key selector (Tier 2 scope, document but mark as deferred)
- [ ] `+` key merge semantics: fetched document **replaces** at the position of the `+` key (not merge)
- [ ] Error behavior for unreachable URLs
- [ ] **URL validation per AD-10** — HTTPS only by default, post-DNS-resolution blocking

**Style class system:**

- [ ] `head.styles` — named style class definitions
- [ ] Component `"class"` — space-separated class name references
- [ ] Jasonette-specific style properties (NOT CSS — enumerate ALL): `color`, `background`, `font`, `size`, `padding`, `padding_top`/`bottom`/`left`/`right`, `corner_radius`, `width`, `height`, `opacity`, `align`, `spacing`, `z_index`, `shy`, `top`, `bottom`, `left`, `right`, **`border`**, **`theme`**, **`move`**, **`resize`**, **`rotate`**, **`dark`**

**Lifecycle hooks:**

- [ ] `$load` — fires once when screen first renders
- [ ] `$show` — fires each time screen becomes visible
- [ ] `$foreground` — fires when app returns from background
- [ ] `$background` — fires when app enters background
- [ ] `$pull` — fires on pull-to-refresh gesture

**Navigation:**

- [ ] `href` (component property, no `$` prefix) — inline navigation on component tap: `url`, `view`, `transition`, `fresh`, `preload`, `options`
- [ ] `$href` (action, with `$` prefix) — programmatic navigation from action chains
- [ ] `view` — enum: `"jason"` (default), `"web"`, `"app"` (canonical lowercase)
- [ ] `transition` — enum: `"push"` (default), `"modal"`, `"fullscreen"`
- [ ] Tab-based navigation config
- [ ] `$back` — pop navigation stack
- [ ] `$close` — dismiss modal

**State management:**

- [ ] `$set` — set local screen state variables
- [ ] `$get` — implicit in templates via `$get.varname`; **clarify: `$get` is a context namespace, not a callable action**
- [ ] `$cache.set` / `$cache.get` / `$cache.reset` — persistent per-URL storage
- [ ] `$session.set` / **`$session.get`** / `$session.reset` — HTTP session/cookie management. **Note: `$session.get` was missing from original plan.**
- [ ] `$global.set` / `$global.get` / `$global.reset` — cross-screen global state (Tier 2)
- [ ] `$flush` — per-URL cache reset shorthand (Tier 1)

**Action execution model:**

- [ ] Action chaining via `success` and `error` continuation handlers. **Note: `success` can be an array** (conditional branching mid-chain per lambda/index.json).
- [ ] `trigger` (recommended form) — shorthand named action invocation
- [ ] `$lambda` (underlying plumbing, not recommended) — explicit `type: "$lambda"` with `options.name`
- [ ] `$return.success` / `$return.error` — return values from named actions (source-documented; no Jasonpedia examples use explicit `$return`)
- [ ] Concurrency: serial within a chain, concurrent across independent triggers
- [ ] Cancellation: navigating away cancels in-flight actions for that screen

**Security model (per AD-8, AD-9, AD-10, AD-11):**

- [ ] Trust model: root JSON server is trusted; mixins, `$params`, `$network.request` responses, and `$get`/`$set` state are secondary trust sources
- [ ] Expression grammar boundary (AD-8)
- [ ] Execution context separation (AD-9)
- [ ] URL validation policy (AD-10)
- [ ] Mixin origin policy (AD-11)
- [ ] `html` component security considerations

**App configuration:**

- [ ] `jasonette.config.json` contract: root URL, debug mode, launch screen behavior, `enforce_https` (default: true), `allow_http` (requires debug), `json_size_limit_mb` (default: 5), `allowed_mixin_origins` (default: `[]` = same-origin only), certificate pins

**v1.x compatibility (merged from former task 0.7):**

- [ ] Breaking changes section: multi-statement expressions, expression grammar restrictions, mixin origin policy, `$script.include` context isolation
- [ ] Exclusion list reference: point to `spec/schema/v1-exclusions.json`
- [ ] Migration path for each breaking change
- [ ] Case-sensitivity: canonical lowercase, accept mixed case

### 0.3 — Action Catalogue

**Output files:** `spec/actions.json` (structured) + `spec/actions.md` (human-readable)

The JSON file enables agent/tool consumption. Format per action:

```json
{
  "$render": {
    "tier": 1,
    "description": "Re-render body with current or specified data",
    "options": {
      "template": {"type": "string", "description": "Named template from head.templates", "required": false},
      "data": {"type": "object", "description": "Override render data", "required": false}
    },
    "success_shape": null,
    "error_shape": null,
    "platform_notes": "All platforms"
  }
}
```

**Tier 1 (v1.0) — Full documentation:**

- [ ] `$render` — Re-render body. Options: `template` (named template selector), `data` (override data)
- [ ] `$reload` — Re-fetch JSON from URL and render
- [ ] `$href` — Navigate (push/modal/web/app/tabs)
- [ ] `$back` — Pop navigation stack
- [ ] `$close` — Dismiss modal
- [ ] `trigger` (recommended) / `$lambda` (explicit form) — Named action invocation
- [ ] `$return.success` / `$return.error` — Return from named action
- [ ] `$network.request` — HTTP request (GET/POST/PUT/DELETE, multipart, headers, data_type). **URL validation per AD-10.**
- [ ] `$set` — Set local state variables
- [ ] `$cache.set` / `$cache.get` / `$cache.reset` — Persistent per-URL cache
- [ ] `$session.set` / `$session.get` / `$session.reset` — HTTP session management
- [ ] `$flush` — Per-URL cache reset shorthand
- [ ] `$util.alert` / `$util.banner` / `$util.toast` — User notifications
- [ ] `$util.picker` / `$util.datepicker` — Selection UI
- [ ] `$util.share` — Share sheet
- [ ] `$timer.start` / `$timer.stop` — Repeating timer
- [ ] `$log` / `$log.info` / `$log.debug` / `$log.error` — Debug output

**Tier 2 (v1.1) — Stub entries (name + one-line description):**

- [ ] `$media.camera` / `$media.picker` / `$media.play` — Photo/video capture, selection, and playback
- [ ] `$network.upload` — File upload (distinct from `$network.request`)
- [ ] `$geo.get` / `$geo.watch` — Location services
- [ ] `$audio.play` / `$audio.record` / `$audio.stop` — Audio
- [ ] `$agent.request` / `$agent.response` — Web container bridge
- [ ] `$global.set` / `$global.get` / `$global.reset` — Cross-screen state
- [ ] `$convert.csv` / `$convert.rss` — Data format conversion
- [ ] `$snapshot` — Screenshot capture
- [ ] `$util.addressbook` — Contact access (corrected namespace)
- [ ] `$notification.register` / `$notification.local` — Local notifications
- [ ] `$default` — Web container default browser behavior

**Tier 3 (v1.2) — Stub entries:**

- [ ] `$oauth` — Authentication (PKCE only)
- [ ] `$websocket.open` / `$websocket.send` / `$websocket.close` — WebSocket
- [ ] `$push.register` / `$push.onNotification` — Push notifications
- [ ] `$script.include` — Load external/inline JavaScript (corrected from `$script.eval`). **Security: runs in script engine context only (AD-9). Functions NOT accessible from JSEP expressions.**
- [ ] `$vision.scan` — Barcode/QR scanning
- [ ] `$widget.banner` — iOS widget notification (may be alias for `$util.banner`)

**Hardware event hooks (distinct from lifecycle hooks):**

- [ ] `$vision.ready` — Scanner hardware ready
- [ ] `$vision.onscan` — Scan completed

### 0.4 — JSON Schema

**Output file:** `spec/schema/jason.schema.json`

Draft 2020-12, `$id: "https://schema.jasonette.dev/v2/jason.schema.json"`

- [ ] Root `$jason` object (required: `head`)
- [ ] `$defs` for reusable types: `component`, `action`, `style`, `expression` (string type), `layout`, **`item`** (distinct from component)
- [ ] Component type discrimination via `oneOf` with `const` on `type` property (better validator performance, code-generator compatibility, and equivalent VS Code support vs `if/then/else`)
- [ ] `head` schema: title (required), description, icon, offline, styles, actions, templates, data, agents (reserve field even though `$agent` is Tier 2)
- [ ] `body` schema: header, footer, sections (**allow array OR template-object**), layers, background, style
- [ ] Component schemas with per-type property constraints. **All components accept optional `href` property.**
- [ ] Layout schemas: vertical, horizontal (**`components` array**, not `items`)
- [ ] Action schemas: type (**enum of known action types**) + options + success (**allow object or array**) + error
- [ ] Style schema: enumerate ALL Jasonette-specific properties including `border`, `theme`, `move`, `resize`, `rotate`, `dark`
- [ ] String properties allow template expressions (`type: string`, no format constraint per AD-4)
- [ ] **URL fields use `format: "uri"` hint** (per AD-4 exception)
- [ ] **`$href.view` uses enum** (`"jason"`, `"web"`, `"app"`)
- [ ] Accept both `dataType` and `data_type` (per AD-5, narrow scope)
- [ ] `patternProperties` with regex for `{{...}}` keys to handle template-as-key patterns
- [ ] **`sections` as `oneOf: [array, object]`** to handle both `[{items}]` and `{"{{#each}}": {}}` forms
- [ ] `$defs` naming: PascalCase nouns (`LabelComponent`, `Style`, `Action`, `Href`)
- [ ] `additionalProperties: false` on component/action variant `$defs` entries (catch typos). Omit constraint on `head`, `body`, `Style` (extension points)
- [ ] Add `default` values where spec defines them (`$href.view` → `"jason"`, `$href.transition` → `"push"`)
- [ ] Structural validation focus — defer `description`/`examples` polish to Milestone 8
- [ ] Keep draft-07 compatibility where possible (avoid `unevaluatedProperties`) for future SchemaStore submission

**Additional schema file:**

- [ ] `spec/schema/v1-exclusions.json` — Machine-readable list of Jasonpedia files excluded from v2.0 validation (per AD-3)
- [ ] `spec/schema/jasonette-config.schema.json` — Schema for `jasonette.config.json` with security-relevant defaults documented

### 0.5 — CI/CD

**Output files:**

- [ ] `.github/workflows/ci.yml` — Change detection entrypoint using `dorny/paths-filter@v3`
  - Path groups: `spec` (`spec/**`, `packages/spec/**`), `web` (`Jasonette-Web/**`), `conformance` (`spec/conformance/**`), `docs` (`**/*.md`)
  - Concurrency control: cancel in-progress on feature branches, never on main
- [ ] `.github/workflows/validate.yml` — JSON Schema validation
  - Trigger: called by ci.yml when `spec` paths change, or on PR to main
  - Steps: checkout, setup Node 20 with npm cache, install ajv-cli, validate Jasonpedia JSON against schema
  - Read exclusion list from `spec/schema/v1-exclusions.json` and skip listed files
  - **Output: structured JSON results** (pass/fail per file)
- [ ] `.github/workflows/lint.yml` — Markdown lint (runs on ALL PRs unconditionally)
  - Uses `DavidAnson/markdownlint-cli2-action@v19`
- [ ] `.github/pull_request_template.md` — (created in task 0.1)

### 0.6 — Conformance Test Skeleton

**Output directory:** `spec/conformance/`

Per AD-2, input-only fixtures in Phase 0:

- [ ] Identify all Jasonpedia files with `head.templates` + `head.data` (eligible: `template/each.json`, `template/if.json`, `template/inline.json`, `template/index.json`, `webcontainer/agent/index.json`)
- [ ] For each: create `spec/conformance/<name>/input.json` (copy of Jasonpedia file)
- [ ] Create `spec/conformance/manifest.yaml` — test case metadata:
  ```yaml
  - id: "template-each-iteration"
    description: "{{#each}} iterates over array and renders item template"
    input: "each/input.json"
    tier: 1
    spec_section: "template.each"
    tags: [template, iteration, tier-1]
  ```
- [ ] Document the conformance test format in `spec/conformance/README.md`
- [ ] Multi-file Jasonpedia demos (pokemon/, feed/) classified as integration test scope — documented but not given fixtures yet
- [ ] Add **adversarial** negative test cases in `spec/conformance/invalid/`:
  - [ ] `prototype-pollution.json` — `{{__proto__.polluted}}` in template expression
  - [ ] `recursive-mixin.json` — A includes B includes A (depth-limit test)
  - [ ] `expression-complexity.json` — 100 deeply nested expressions (complexity-limit test)
  - [ ] `javascript-url.json` — `$href` with `"url": "javascript:alert(1)"`
  - [ ] `file-url-mixin.json` — mixin `@` with `file:///etc/passwd`
  - [ ] `oversized-document.json` — 100MB valid JSON (size-limit test)

---

## Non-Goals (Deferred)

- Writing any rendering code (Phase 0.5+)
- Platform-specific project setup (Phase 1+)
- Community announcement (Phase 4+)
- Interactive playground (cut from v1.0 per D9)
- `keyname@url` mixin form (Tier 2 scope, document but don't schema-validate)
- Conformance test expected outputs (Milestone 2 — template engine generates ground truth)
- JSON Schema `description`/`examples` polish (Milestone 8)
- Regex expression support in templates (defer to Milestone 2; ReDoS risk needs mitigation strategy)

## Success Criteria

- [ ] All in-scope Jasonpedia JSON files validate against the JSON Schema (v1.x exclusion list in `spec/schema/v1-exclusions.json`)
- [ ] Action catalogue covers every action found in Jasonpedia + cross-reference with iOS/Android/Web source. Both `spec/actions.json` (structured) and `spec/actions.md` (readable) exist.
- [ ] CI passes on the feature branch (schema validation + markdown lint)
- [ ] Spec defines formal expression grammar, execution context boundary, URL validation policy, and mixin origin policy
- [ ] At least 5 conformance test input fixtures + 6 adversarial negative test cases
- [ ] Security model documented: trust model, SSRF protection, sandbox boundary, `html` component warning
- [ ] PR opened, reviewed, and merged into main

## Task Ordering

Execute in this order (dependencies flow downward):

```
0.1 Scaffolding (no dependencies)
 ↓
0.2 Spec (needs directory structure from 0.1)
 ↓
0.3 Action Catalogue (needs spec vocabulary from 0.2)
 ↓
0.4 JSON Schema (needs spec + catalogue from 0.2, 0.3)
 ↓
0.5 CI/CD (needs schema from 0.4)
 ↓
0.6 Conformance Tests (needs schema + CI from 0.4, 0.5)
```

## Estimated Effort

3-5 days for a single implementor with AI assistance. The spec extraction (0.2) is the heaviest task — requires reading all 100 Jasonpedia files and cross-referencing with iOS/Android/Web source code. The scope simplifications (Tier 1 catalogue only, input-only fixtures, deferred schema polish) reduce the original estimate by ~30%.
