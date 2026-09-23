# Web HTML iframe browser smoke test — 2026-09-23

## Scope and environment

- Commit under test: `2e1a4d1` on `main`, including merged PR #25.
- Host: macOS 26.2 (25C56), system `WKWebView` (`WebKit.framework` version
  `21623`). This runs the browser engine, not the Safari application.
- Bundle: freshly built `packages/web-renderer/dist/jasonette.umd.js` from
  `npm run build --workspace @jasonette/web`.
- Fixture: a localhost parent page using `JasonetteRenderer.renderDocument` to
  create HTML components and HTML body backgrounds from inline text and URLs.

## Reproduce

From the repository root, build the Web renderer and generate the fixture:

```bash
npm run build --workspace @jasonette/web
python3 docs/qa/browser-web-html/fixture.py
```

Serve the fixture in one terminal:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 \
  --directory /private/tmp/jasonette-browser-fixture
```

Compile and run the WebKit probe in another terminal:

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/jasonette-clang-cache \
  clang -fobjc-arc -framework AppKit -framework WebKit \
  -o /private/tmp/jasonette-wk-runner \
  docs/qa/browser-web-html/webkit-runner.m
/private/tmp/jasonette-wk-runner
```

The saved successful browser snapshot is
[`browser-web-html/result.json`](browser-web-html/result.json). The probe exits
zero only when all four cases pass.

## Result

| Renderer path | Source | Child script | Event origin | Parent DOM and storage | Child storage | Top navigation |
| --- | --- | --- | --- | --- | --- | --- |
| HTML component | Inline `text` | Ran | `null` | `SecurityError` | `SecurityError` | `SecurityError` |
| HTML component | Local URL | Ran | `null` | `SecurityError` | `SecurityError` | `SecurityError` |
| HTML background | Inline `text` | Ran | `null` | `SecurityError` | `SecurityError` | `SecurityError` |
| HTML background | Local URL | Ran | `null` | `SecurityError` | `SecurityError` | `SecurityError` |

All four iframes had `sandbox="allow-scripts"`. The parent retained its
`localStorage` marker and remained at the fixture URL. The parent received no
uncaught JavaScript errors. The URL child pages reported their URL origin from
`location.origin`; their `postMessage` event origin was `null`, and storage and
parent access were denied. The event origin and access results show the sandbox
origin enforced by WebKit.

One fresh-build attempt created all four iframes and fetched both URL pages but
timed out before receiving any child messages. The subsequent fresh-build run
passed all assertions and produced the saved snapshot. The runner treats a
missing report as inconclusive, so a cold-start timeout should be retried.

This smoke test covers WebKit's enforcement on this macOS host. It does not
establish behavior in Chromium or Firefox, and the iframe sandbox does not
promise network isolation; the URL cases intentionally fetched local pages.
