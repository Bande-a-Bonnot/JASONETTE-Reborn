---
id: "019f2f53-52f5-7784-9534-0e1e070975a1"
status: complete
priority: p2
issue_id: "069"
tags: [web, parity, html, components, jasonpedia]
dependencies: []
---

# Web HTML component CSS parity

## Problem Statement

The Jasonpedia HTML component fixture (`Jasonpedia/view/component/html/index.json`)
authors inline HTML plus a sibling `css` string. The current web renderer
created a `srcdoc` iframe for `text`, but ignored the component `css`, so the
fixture did not preserve the authored HTML styling contract used by current iOS
and the shared Jasonpedia fixture.

A quick reference check found the legacy `Jasonette-Web/src/components.js` did
not implement an HTML component-specific external CSS contract; this todo is
therefore scoped to the authored inline `css` field on the HTML component, not
to fetching sibling/external CSS files.

## Acceptance Criteria

- HTML components with `text` and `css` include the CSS in the iframe `srcdoc`.
- HTML components with `url` keep using iframe `src` and do not pretend to inject
  CSS into cross-origin documents.
- Jasonpedia `view/component/html/index.json` has web fixture coverage proving
  the component CSS reaches `srcdoc`.

## Completed

Implemented `htmlSrcdoc()` in `packages/web-renderer/src/components/index.ts` to
prefix authored component CSS as a `<style>` tag before inline HTML. Added
component-level coverage for inline CSS and URL-backed HTML behavior, plus a
Jasonpedia fixture smoke test for `view/component/html/index.json`.

## Verification

```bash
npm run test --workspace=@jasonette/web -- components.test.ts integration.test.ts
npm run typecheck --workspace=@jasonette/web
```
