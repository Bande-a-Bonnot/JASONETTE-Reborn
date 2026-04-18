---
status: ready
priority: p3
issue_id: "024"
tags: [ios, swiftui, sdui, rendering, style-application]
dependencies: []
---

# FooterTabItemView may clip caption when fixture sets a small height

## Problem Statement

`FooterTabItemView` (in `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift`) applies `JasonStyleModifier(style: item.style, headStyles:, className:)` to the outer `VStack` that contains icon + caption. `JasonStyleModifier.applySize` translates a `height` style into `.frame(maxHeight:)` on the whole modifier target.

Real Jasonpedia fixtures (`Jasonpedia/view/footer/tabs.json`) set `"height": "21"` intending the icon size — but the modifier now applies that 21pt cap to the whole cell (icon + badge + caption). The caption can be clipped or the hit area visibly shrinks.

Before PR #17, the hard-coded `.frame(width: 24, height: 24)` on the icon decoupled the icon size from the cell size, so this bug wasn't visible.

## Findings

- Location: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift` — FooterTabItemView body, after the `.modifier(JasonStyleModifier(...))` call
- `resolvedStyle()` helper (introduced in `604eaa7`) resolves `iconWidth`/`iconHeight` correctly from the merged style, so the icon draws at the right size
- The bug is that the *same* style is *also* applied to the VStack via the modifier, capping the full cell
- Not flagged by any reviewer in round 1 or round 2 — this is an authored follow-up

## Recommended Action

Three options, in increasing order of risk:

1. **Narrow the modifier scope**: apply `JasonStyleModifier` to the icon container (ZStack) only, so sizing styles apply to the icon, not the cell. Keep the VStack unstyled.
2. **Separate icon style from cell style**: introduce a convention where `height`/`width` on a footer tab item targets the icon and other style properties (padding, opacity, color) apply to the cell. Document in `docs/solutions/`.
3. **Fixture-side fix**: update `Jasonpedia/view/footer/tabs.json` to express icon height as a nested `image.style.height` rather than a top-level `style.height`. Breaks compatibility with legacy demos.

Option 1 is likely correct: in the generic renderer, style applies to the component; in a structural view where the component is a composite, style should apply to the visually-dominant child, not the outer container.

## Acceptance Criteria

- [ ] Tab items with `{"height": "21"}` render captions without clipping
- [ ] Icon still respects the `height` style
- [ ] Unit test covering: fixture with small `height` → caption visible, icon sized correctly
- [ ] No regression on tab items that set padding/opacity/color (those should still apply)

## Notes

Related: `docs/solutions/best-practices/typeless-structural-items-need-dedicated-views.md` (the pattern doc for this view).

Surfaced during PR #17 authoring, not in review. Filing as P3 because the demo fixture currently renders acceptably (the 21pt cap leaves enough room), but it's a latent bug the next fixture with a smaller height will trigger.

Source: PR #17 review loop, 2026-04-18.
