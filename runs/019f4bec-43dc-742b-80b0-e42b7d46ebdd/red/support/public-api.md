# Public API Contract Available to Red

Tests run in the Jasonette Reborn npm workspace and may import only:
- `@jasonette/template-engine`: `transform`, `renderSync`; public context/options types.
- `@jasonette/web`: `JasonetteRenderer`, `renderComponent`, `executeAction`; public document/action/state types.

Use Vitest and jsdom. Do not reference source/implementation paths. Write Gherkin under `features/` and executable tests under `tests/`. Allowed fixture: `support/fixtures/jasonpedia-html-index.json`.
External command/typecheck/build/CI obligations must be typed external pending evidence, never fabricated Vitest assertions.
