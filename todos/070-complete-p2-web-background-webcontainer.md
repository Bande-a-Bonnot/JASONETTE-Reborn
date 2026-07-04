---
id: "019f2f5a-495d-7137-ac8f-826493002d86"
status: complete
priority: p2
issue_id: "070"
tags: [web, parity, background, webcontainer, jasonpedia]
dependencies: []
---

# Web body background web container parity

## Problem Statement

Legacy Jasonette-Web has a `WebContainer` helper (`Jasonette-Web/src/web.js`)
that updates an iframe with either `background.url` or `background.text`.
Jasonpedia webcontainer fixtures also author HTML backgrounds under
`body.style.background`, for example `Jasonpedia/webcontainer/d3gauge.json`.
The current web renderer only handled string backgrounds as colors/images, so
HTML background containers were silently ignored.

## Acceptance Criteria

- `body.background` with `{ type: "html", url: ... }` renders an iframe web
  background.
- Legacy templated `body.style.background` with `{ type: "html", text: ... }`
  renders an iframe web background.
- The web background is inserted behind foreground document content and anchored
  to the Jasonette root, not the viewport.

## Completed

Added web background rendering in `JasonetteRenderer`: string backgrounds still
map to image/color root styles, while HTML background objects render an
`aria-hidden` `.jasonette-background-web` iframe before foreground sections.
Updated base CSS so `.jasonette` establishes a relative clipped containing block
and foreground children layer above the background iframe.

## Verification

```bash
npm run test --workspace=@jasonette/web -- renderer.test.ts integration.test.ts
npm run typecheck --workspace=@jasonette/web
npm run build --workspace=@jasonette/web
```
