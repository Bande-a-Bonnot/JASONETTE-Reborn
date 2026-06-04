---
id: "019e947d-d65f-79dd-9462-0658b42d899b"
status: open
priority: p2
issue_id: "057"
tags: [ios, actions, geo, qa, jasonpedia]
dependencies: []
---

# Investigate iOS `$geo.get` success rendering in Jasonpedia fixture

## Context

The delegated iOS action-screen QA pass on 2026-06-03 found that the direct
`Jasonpedia/action/geo/index.json` fixture shows the system location permission
prompt, but after granting permission the `Display` and `Map` actions did not
visibly render coordinates or a map, even after setting a Simulator location.

Evidence:

- `docs/qa/2026-06-03-ios-action-screen-qa.md`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/geo-initial.png`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/geo-after-display.png`

## Ask

Verify whether the failure is in the CoreLocation callback, `$geo.get` payload
shape, template/render success chain, or the Jasonpedia fixture. Make the success
path visibly render and make no-error-action failure cases user-visible enough
for QA.

## Acceptance Criteria

- [ ] The direct geo fixture visibly renders coordinates after granting location.
- [ ] The map branch visibly renders or has a documented fixture/runtime reason
      why it cannot.
- [ ] Denial/failure behavior is user-visible when the fixture has no authored
      `error` branch.
- [ ] Add regression coverage for the identified payload/render path.
- [ ] Run targeted geo tests and full `swift test`.
