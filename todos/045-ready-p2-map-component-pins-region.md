---
id: "019e53ff-7aed-7e1f-8848-2b1324a4531c"
status: ready
priority: p2
issue_id: "045"
tags: [ios, components, map, renderer, qa]
dependencies: []
---

# Implement map component pins and region support

## Problem Statement

The iOS renderer recognizes `type: "map"`, but it currently renders a stub. The
handoff Phase C audit still lists map pins/region as an unimplemented component
fix, so Jasonette map demos cannot show authored locations meaningfully.

## Evidence

- Handoff Phase C: map is listed as `map (stub — no pins/region)`.
- Renderer file: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/MapStubComponent.swift`.

## Recommended Action

1. Inventory Jasonpedia/spec map fixtures and identify the authored fields for
   region, coordinates, pins/annotations, labels, and any user-location options.
2. Extend `JasonComponent` decoding only for the fields actually needed by the
   fixture/spec.
3. Replace or augment `MapStubComponent` with a MapKit-backed SwiftUI renderer.
4. Add unit/fixture tests for decoding and renderer path selection.
5. Run simulator visual QA against at least one Jasonpedia map fixture.

## Acceptance Criteria

- [ ] `type: "map"` renders an actual map instead of only a stub placeholder
- [ ] Authored region/center/zoom data is honored where present
- [ ] Authored pins/annotations are visible where present
- [ ] Tests cover map fixture decoding and renderer path selection
- [ ] Simulator QA screenshot confirms a map fixture renders meaningfully

## Notes

Keep scope to Jasonette fixture parity first; advanced interactions such as live
user tracking can follow separately if needed.
