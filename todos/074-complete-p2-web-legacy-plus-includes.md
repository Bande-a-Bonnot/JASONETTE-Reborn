---
id: "019f2fa2-a333-7979-8184-dd48cc427656"
status: complete
priority: p2
issue_id: "074"
tags: [web, parity, preprocessing, includes, webcontainer]
dependencies: ["066", "073"]
---

# Web legacy plus include preprocessing

## Problem Statement

Legacy Jasonette Web resolves mixins/includes before rendering. Jasonpedia
webcontainer fixtures use the legacy `+` include form for full-document remote
templates, selector includes such as `items@...`, template component includes,
and local `$document...` references inside fetched templates. The current web
renderer loaded raw JSON and rendered synchronously, so fixtures such as
`Jasonpedia/webcontainer/pdf.json` and `Jasonpedia/webcontainer/feed/index.json`
under-rendered.

This is backed by the parity audit's legacy document preprocessing/includes gap
and by the legacy `Jasonette-Web/src/mixin.js` reference behavior.

## Acceptance Criteria

- Web `load()` resolves legacy `+` includes before storing/rendering documents.
- Remote full-document includes merge fetched objects with local fields.
- Selector includes like `items@url` and `item@url` select the referenced key.
- Local includes like `{ "+": "$document.title" }` resolve against the merged
  root document, preserving root-only fields when a remote template is expanded.
- Jasonpedia webcontainer PDF and feed fixtures render through the normal web
  renderer load path.
- Unsafe non-HTTP(S) include URLs are not fetched.
- Cycle protection is scoped to the current include chain so repeated or
  different-selector includes from the same URL can still resolve independently.

## Completed

Added a bounded legacy `+` include resolver to the web renderer load path. It
resolves remote includes relative to the loaded/fetched document URL, supports
selector forms, merges object includes with local overrides, blocks unsafe
schemes, uses a per-chain include stack for cycle protection, and resolves local
`$document...` references after the top-level merge. Added integration coverage
for the webcontainer PDF template, feed item/template includes, duplicate
same-URL selector includes, and blocked unsafe include schemes.

## Verification

```bash
npm run test --workspace=@jasonette/web -- integration.test.ts
npm run typecheck --workspace=@jasonette/web
npm run test --workspace=@jasonette/web
npm run build --workspace=@jasonette/web
```
