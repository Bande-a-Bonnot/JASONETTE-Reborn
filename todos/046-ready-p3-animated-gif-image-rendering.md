---
id: "019e53ff-7aed-7e53-ab57-92c80a6d6f9e"
status: ready
priority: p3
issue_id: "046"
tags: [ios, components, image, gif, renderer, qa]
dependencies: []
---

# Support animated GIF image rendering

## Problem Statement

The handoff Phase C audit still lists animated GIF support as a missing iOS
renderer component fix. Current image rendering is SwiftUI/`AsyncImage`-oriented
and should be audited because GIFs may render as static first frames or fail to
animate.

## Evidence

- Handoff Phase C: animated GIF remains listed as not implemented.
- Renderer file: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/ImageComponent.swift`.

## Recommended Action

1. Identify Jasonpedia/spec fixtures that use GIFs.
2. Determine current behavior in simulator: static first frame, blank, or other.
3. Choose a native implementation strategy, likely a small UIKit-backed
   `UIImageView`/animated image wrapper for GIF URLs/data, while preserving the
   existing static image path.
4. Keep URL resolution and scheme policy aligned with existing `ImageComponent`
   behavior and `todos/036` if that policy lands first.
5. Add regression tests for GIF renderer path selection and run simulator QA.

## Acceptance Criteria

- [ ] GIF image fixtures animate on iOS
- [ ] Static images still render via the existing path
- [ ] Relative GIF URLs resolve against `documentURL`
- [ ] Tests cover GIF detection/path selection
- [ ] Simulator QA evidence captures a GIF fixture rendering/animating, or a
      documented best-effort visual check if animation cannot be represented in
      a still screenshot

## Notes

This is lower priority than map/HTML because static image rendering already
works for common fixtures.
