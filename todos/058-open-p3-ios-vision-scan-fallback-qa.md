---
id: "019e947d-d661-70de-a7ff-6820771a871e"
status: open
priority: p3
issue_id: "058"
tags: [ios, actions, vision, fallback, qa]
dependencies: []
---

# Verify iOS `$vision.scan` fallback is user-visible

## Context

The delegated iOS action-screen QA pass on 2026-06-03 found that the direct
`Jasonpedia/action/vision/index.json` fixture stayed on `Scanning...`; no
recognized fallback alert was observed after launch/waiting.

Evidence:

- `docs/qa/2026-06-03-ios-action-screen-qa.md`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/vision-initial.png`

## Ask

Confirm whether `$vision.scan` is dispatched on this fixture's launch path. If it
is dispatched, make unsupported native vision scanning show explicit fallback
feedback. If it is not dispatched because `$vision.ready` never fires without a
camera background implementation, document and/or improve the unsupported state.

## Acceptance Criteria

- [ ] Direct vision fixture behavior is understood and documented.
- [ ] Unsupported `$vision.scan` does not appear as a silent no-op in Jasonpedia.
- [ ] Add regression coverage for the relevant fallback/unsupported path.
- [ ] Run targeted action tests and full `swift test`.
