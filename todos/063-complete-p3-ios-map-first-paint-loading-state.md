---
id: "019eb90b-264d-739d-8d97-3bf6f5861b49"
status: complete
priority: p3
issue_id: "063"
tags: [ios, qa, map, component, jasonpedia]
dependencies: []
---

# Investigate iOS map first-paint loading state

## Problem Statement

The 2026-06-11 iOS Simulator UI QA pass observed that the Jasonpedia map
component fixture changes materially between an early screenshot and a later
screenshot. The early capture already shows map content, so this is not a clear
blank-render regression, but tile/layout settling can still look like a stale or
under-rendered first paint on slower launches.

Evidence:

- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/09-component-map-shortwait.png`
- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/09-component-map-longwait.png`

## Follow-up Result

A focused direct-entry recheck on the pinned iPhone 17 Pro simulator showed the
map fixture fully rendered by the 3-second capture and remained pixel-identical
at 6, 10, and 15 seconds. The earlier QA finding appears to have been normal
launch/network variability rather than a renderer defect. No code change or
placeholder is needed right now.

## Acceptance Criteria

- [x] Re-run direct-entry QA for
      `Jasonpedia/view/component/map/index.json` with timestamped screenshots at
      short intervals after launch.
- [x] Decide whether current MapKit tile settling is acceptable or whether the
      renderer should show an explicit placeholder/loading affordance.
- [x] If a placeholder is needed, implement it without regressing the existing
      native map/pin rendering behavior. Not needed after recheck.
- [x] Document the result in `docs/qa/` and mark this todo complete.

## Verification

- Direct-entry Simulator smoke via local Jasonpedia HTTP server and pinned iPhone
  17 Pro UDID captured screenshots at approximately 3, 6, 10, and 15 seconds:
  - `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/24-map-recheck-03s.png`
  - `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/24-map-recheck-06s.png`
  - `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/24-map-recheck-10s.png`
  - `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/24-map-recheck-15s.png`
- Pixel diff results: 0.0000 mean difference and 0.0000% changed pixels between
  3→6s, 6→10s, and 10→15s screenshots.
