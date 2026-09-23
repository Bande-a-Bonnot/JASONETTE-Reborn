# Red Corpus Repair Plan

Source of truth: the reviewed NLSpec at
`docs/nlspecs/2026-07-10-web-html-component-safety.nlspec.md`, especially sections
3.1–3.5 and 6.5–6.8. Edit only this retry's copied corpus under `red/`; preserve
the original July corpus unchanged.

## Corrections

1. Make `templatedDocument()` put initial template data in `$jason.head.data`,
   the renderer's established document data field. Keep the body template and
   all expected raw HTML text behavior unchanged.
2. Correct the unresolved **inline** expression expectation to the existing
   generic behavior (`prefix  suffix`). Keep the standalone unresolved-string
   behavior assertion separate and unchanged.
3. Assert the authored border contract with `iframe.style.border === 'none'`
   instead of assuming jsdom populates four longhand border properties.
4. Review `integration-smoke.test.ts` after the data correction. Keep transform
   coverage for every required body-tree shape. For DOM assertions, use slots
   the renderer actually supports; the NLSpec's concrete DOM smoke is section
   3.5. Do not require iframe DOM from unsupported header/footer `items`,
   layout `items` instead of `components`, or nested `section.items` arrays.
5. Embedded HTML-shaped action options/payload stay raw immediately after the
   body transform. After the action executes, the separate generic option
   transform applies. Correct click-time assertions accordingly.

## Verification and barrier

- Do not edit Green product source, Green plan/brief, or the original July corpus.
- Preserve meaningful assertions for own-field selection, iframe policy/order,
  body-mode propagation, action-time generic behavior, and integration liveness.
- Keep case titles stable where possible so filtered PASS/FAIL feedback remains
  comparable. If a case changes shape, update `case-catalog.mjs`, features, and
  coverage map consistently.
- Run `node red/tests/verify-coverage-map.mjs`; it must pass with the new corpus.
- Return a concise list of exact files changed and evidence. Do not send Red
  assertions or failure details to Green.
