---
id: "019e53ff-7aed-7e1f-8848-2b1324a4531c"
status: complete
priority: p2
issue_id: "045"
tags: [ios, components, map, renderer, qa]
dependencies: []
---

# Implement map component pins and region support

Completed: 2026-05-23

## Resolution

Implemented MapKit-backed map rendering for the iOS renderer:

- `JasonComponent` now decodes authored `region` and `pins` map fields.
- `JasonStyle.selected` decodes/merges for map pin selected-callout semantics.
- `MapComponent` parses `lat,lng` coordinates, honors authored region width/height as meters, renders map annotations, and shows a callout-like title/description bubble when `style.selected` is truthy.
- `ComponentView` routes `type: "map"` through `MapComponent` instead of the prior placeholder/stub path.
- ComponentDispatch, StyleModifier, and ViewModel fixture tests cover decoding, helper parsing, renderer registration, Jasonpedia fixture selection, and annotations.
- Simulator QA evidence: `docs/qa/2026-05-23-ios-map-component-qa.md` and screenshots in `docs/qa/artifacts/2026-05-23-ios-map-component/`.

## Problem Statement

The iOS renderer recognized `type: "map"`, but it only rendered a stub. The
handoff Phase C audit listed map pins/region as an unimplemented component
fix, so Jasonette map demos could not show authored locations meaningfully.

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

- [x] `type: "map"` renders an actual map instead of only a stub placeholder
- [x] Authored region/center/zoom data is honored where present
- [x] Authored pins/annotations are visible where present
- [x] Tests cover map fixture decoding and renderer path selection
- [x] Simulator QA screenshot confirms a map fixture renders meaningfully

## Notes

Keep scope to Jasonette fixture parity first; advanced interactions such as live
user tracking can follow separately if needed.
