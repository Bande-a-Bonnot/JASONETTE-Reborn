---
id: "019eb90b-264f-752d-aa8e-ebc3f61c93f4"
status: complete
priority: p3
issue_id: "064"
tags: [ios, qa, jasonpedia, audio, ats, fixtures]
dependencies: []
---

# Replace HTTP media URLs in the Vault Boy audio fixture

## Problem Statement

The 2026-06-11 iOS Simulator UI QA pass found that
`Jasonpedia/action/audio/vaultboy/index.json` renders as a mostly blank page on
iOS because its preview/background GIF URLs use insecure `http://` URLs blocked
by App Transport Security.

Evidence:

- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/20-action-audio.png`
- Simulator log reported `NSURLErrorDomain Code=-1022` for
  `http://i.giphy.com/l41YybJPL0z2n1snm.gif`.

## Fix

Updated the fixture `preview` and `body.style.background` GIF URLs from
`http://i.giphy.com/l41YybJPL0z2n1snm.gif` to
`https://i.giphy.com/l41YybJPL0z2n1snm.gif`.

## Acceptance Criteria

- [x] The Vault Boy fixture uses HTTPS media URLs or a maintained HTTPS-hosted
      replacement asset.
- [x] Launching the fixture no longer emits ATS `-1022` failures for the GIF
      preview/background.
- [x] The fixture visibly renders its intended media/background on iOS.
- [x] `$audio.play` behavior remains covered by existing tests/QA.

## Verification

- `curl -I -L --max-time 15 https://i.giphy.com/l41YybJPL0z2n1snm.gif` —
  returned HTTP 200.
- `jq empty Jasonpedia/action/audio/vaultboy/index.json && npm run spec:validate`
  — 80 passed, 5 excluded.
- `npm run lint:md` — 0 errors.
- Direct-entry Simulator smoke via local Jasonpedia HTTP server and pinned iPhone
  17 Pro UDID captured visible Vault Boy media at
  `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/22-action-audio-vaultboy-https.png`.
