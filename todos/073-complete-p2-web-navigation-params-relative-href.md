---
id: "019f2f98-dc27-7ca6-b113-aa2965758d75"
status: complete
priority: p2
issue_id: "073"
tags: [web, parity, navigation, params, href]
dependencies: ["066", "072"]
---

# Web navigation params and relative href parity

## Problem Statement

The web renderer exposed `$params` in render contexts, but navigation did not
populate it. `$href` also resolved relative URLs against `document.baseURI`
rather than the current Jasonette document URL. Legacy Jasonette navigation
flows pass `href.options.options` into the destination as `$params` and resolve
relative document links against the currently loaded document, including final
loaded URLs after redirects.

This gap is part of the parity audit's navigation/render-context findings and
is already covered on iOS by document-URL-relative navigation tests.

## Acceptance Criteria

- `load()` stores the final response URL in renderer state so later relative
  navigation uses the loaded document URL.
- `$href` resolves relative `options.url` values against the current document
  URL, while preserving existing blocked-scheme behavior.
- `navigate(url, { options })` exposes nested `options` as `$params` in the
  destination render context.
- Push navigation history stores/restores `$params` on `back()`.
- Reloads preserve current params, and navigation errors are caught/logged
  instead of becoming unhandled rejections.

## Completed

Updated the web action `$href` handler to resolve relative URLs against
`state.url`. Updated renderer loading/navigation to store `response.url` as the
current document URL, carry `options.options` into `state.params`, preserve params
through push/back and reload, and shallow-clone params when writing history.

Added Vitest coverage for relative `$href` resolution, final response URL
storage, `$params` rendering after `load()`, relative push navigation with params,
and internal `back()` param restoration.

## Verification

```bash
npm run test --workspace=@jasonette/web -- actions-parity.test.ts renderer.test.ts
npm run typecheck --workspace=@jasonette/web
npm run test --workspace=@jasonette/web
npm run build --workspace=@jasonette/web
```
