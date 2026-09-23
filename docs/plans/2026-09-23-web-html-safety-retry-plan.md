# Web HTML template and iframe safety: Green implementation plan

Source of truth: `docs/plans/green-brief.md` in the isolated workspace, extracted from sections 1–5 of `docs/nlspecs/2026-07-10-web-html-component-safety.nlspec.md`. This plan covers product changes only in the isolated workspace.

## Constants and contracts

- Template option: `RenderOptions.preserveHtmlText?: boolean`, with omitted/undefined/false all meaning false. Pass `{ preserveHtmlText: true }` to both selected body-template `renderSync` calls. Pass the same options object into every recursive `transform` call.
- Exact shape keys and value: `HTML_TYPE = 'html'`, `HTML_TEXT_KEY = 'text'`, and resolved type key `'type'`. Protection applies only when the **last** transformed own entry whose resolved key is `'type'` is the primitive string `'html'`.
- Iframe policy: `HTML_SANDBOX = 'allow-scripts'`. Set the attribute once, immediately after `document.createElement('iframe')` and before either `srcdoc`, `src`, or insertion. Do not add `allow-same-origin` or any other token.
- Source priority: own, nonempty string `text` wins over own, nonempty string `url`; otherwise no iframe. Own, nonempty string `css` is used only for inline `srcdoc`. Escape every case-insensitive `</style` to the code units `<`, U+005C, `/style` (one runtime backslash).
- Safe copy descriptor: `Object.defineProperty(target, key, { value, enumerable: true, writable: true, configurable: true })`. Use this for every transformed output key and the named state sinks, including `__proto__`, `constructor`, and `prototype`.
- Keep all output and state objects ordinary (`Object.prototype`), including stored sessions and the session registry. Do not use inherited registry entries for component renderers, action handlers, named actions, or sessions.

## Affected source and integration points

| File | Work |
| --- | --- |
| `packages/template-engine/src/types.ts` | Add the optional `preserveHtmlText` field to `RenderOptions`. |
| `packages/template-engine/src/transformer.ts` | Keep the existing generic per-entry key-then-value order when the option is off; replace regular-object assignment with descriptor-safe definition. In body mode, collect entries in `Object.keys()` order, interpolate every key exactly once, pre-transform every resolved `type` entry exactly once, derive final type from the last such entry, then process entries in order while passing through each resolved `text` original value unchanged only for final `html`. Keep existing directive selection and recursive option propagation for arrays and `#if`/`#elseif`/`#else`/`#each`. |
| `packages/web-renderer/src/renderer.ts` | Enable body mode at both `renderDocument()` and `renderBody()` template calls (the latter is reached by actual `$render`). Select background with own-path checks and nullish canonical-over-legacy precedence. Require own exact `type: 'html'` before the HTML path. Reuse the common HTML iframe source/composition helper; insert it directly into the root before foreground sections. Protect fixed named-action lookups such as lifecycle, `$load`, and `$pull` where applicable. |
| `packages/web-renderer/src/components/index.ts` | Use an own-callable renderer lookup and own `component.type`; missing/inherited/non-string type falls back to `label`, while an own unknown string yields the visible unknown component. Centralize `ownValue`, source selection, CSS composition, and iframe creation so component and background paths have identical source/sandbox behavior. Preserve wrapper class/data marker and iframe width/border. Make registration safe for prototype-colliding keys. |
| `packages/web-renderer/src/actions/index.ts` | Use own-callable handler lookup and own `type`/`trigger` dispatch. Named trigger and `$lambda` lookups accept only own action objects or arrays. Keep option/continuation transforms generic. Replace `Object.assign` in `$set`, `$cache.set`, `$global.set` with descriptor-safe own copy. Store `$session.set` options in a new ordinary safely copied object and define the normalized domain safely on `state.sessions`; `requestSession()` accepts only an own domain. Keep registration safe for prototype-colliding keys. |
| `packages/web-renderer/src/types.ts` | Widen the background type to model optional `type`, `text`, `url`, and `css` on canonical and legacy paths; include `body.style.background` explicitly if useful for compile-time clarity. Runtime own-field and string checks remain authoritative. |

`packages/template-engine/src/render.ts` already passes `RenderOptions` into `transform` from both `render` and `renderSync`; no behavior change is needed there unless extraction makes it necessary. `packages/web-renderer/src/layouts/index.ts` delegates regular components to `renderComponent`; review its layout type checks for inherited `type` before finalizing, but preserve layout behavior for valid own types. The Jasonpedia fixture is read through `JasonetteRenderer`; do not rewrite it.

## Sequence

1. Implement the option and safe regular-object transform. Address resolved key/type collisions, strict text identity, directives/nesting, getter order (`Object.keys()` numeric ordering included), and dangerous resolved keys. Ensure the off-mode existing key-then-value order and unresolved-expression behavior remain intact.
2. Implement the common component/background source, composition, and iframe helper. Source selection must happen before iframe creation so no-source calls produce no iframe trace. After creation the security-observed order must be `CREATE -> SANDBOX('allow-scripts') -> SOURCE('srcdoc'|'src') -> APPEND -> RETURN`, with no intervening sandbox event. Component completion is public `renderComponent()` return in direct calls and the data-type marker in integrated calls; background completion is `renderBodyBackground()` return. Do not attach both source attributes.
3. Enable body mode in initial and `$render` template selection. Implement own canonical/legacy background location selection: use non-nullish own `body.background` even if malformed or source-free; otherwise use own `body.style.background` only when `style` is an own object. Inherited path segments never select a background. Keep background iframe before sections.
4. Harden component and action registries, dispatch, state writes, and session lookup. Inherited/missing/non-string component types use label default; own unknown/prototype-colliding strings use unknown element. Inherited action `type` with own string `trigger` may dispatch only an own valid named action; unknown own string `type` returns `undefined` without continuation. Check named `toString`, `constructor`, and `__proto__` for both trigger and `$lambda`. Maintain ordinary object prototypes and own inert descriptors at both session levels.
5. Run the full initial-to-`$render` flow and Jasonpedia rendering. Check first/new iframe identity, both iframe sandbox endpoints, literal HTML expression, changed style and label, and rendered CSS/text in the fixture. Check action-time `$set` still interpolates `probe.text` generically.
6. Run the required commands below in order. A local full-Web CLI timeout is acceptable only if every other local test passes, isolated `cli.test.ts` passes, and exact implementation-SHA Web CI passes; document that timeout. Any other test failure or missing/failing exact-SHA CI fails acceptance. No jsdom result is evidence of browser-enforced origin, script, host-storage, navigation, or network behavior.

## Likely risks and checks

- **Evaluation order:** a one-pass body transform can classify text before later resolved `type` entries and can invoke getters in the wrong order. Keep the three-pass logic local to each regular-object frame; do not change generic mode ordering.
- **Prototype names:** plain assignment can invoke the legacy `__proto__` setter. Treat interpolation output and normalized session domains as property names to define, never direct-assignment targets. `Object.fromEntries` in `loadSessions()` already creates own properties, but confirm the returned registry has `Object.prototype` and request lookup rejects inherited domains.
- **Iframe timing:** setting source before sandbox can expose content before policy. Centralize creation so both paths share policy; do not let wrapper styling, root insertion, or completion markers move the sandbox/source order.
- **Own-field semantics:** inherited `text`, `url`, `css`, `type`, action names, and background path segments currently pass through several direct property reads. Use `Object.hasOwn()` before reading fields at these boundaries, including when values are false, empty, null, or malformed.
- **Types versus runtime:** malformed authored values are valid safety vectors. Narrow TypeScript interfaces must not substitute for runtime string/own-property checks. Keep invalid HTML unchanged and avoid source coercion.

## Required verification commands

```sh
npm run test --workspace=@jasonette/template-engine -- transformer.test.ts
npm run test --workspace=@jasonette/web -- components.test.ts integration.test.ts actions-parity.test.ts renderer.test.ts
npm run typecheck --workspace=@jasonette/template-engine
npm run typecheck --workspace=@jasonette/web
npm run build --workspace=@jasonette/template-engine
npm run build --workspace=@jasonette/web
npm run test --workspace=@jasonette/template-engine
npm run test --workspace=@jasonette/web
```

If the full Web run alone times out in `cli.test.ts`, run the isolated CLI test with `npm run test --workspace=@jasonette/web -- cli.test.ts` and require exact implementation-SHA Web CI before acceptance.
