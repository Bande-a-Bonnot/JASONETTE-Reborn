---
status: complete
priority: p2
issue_id: "024"
tags: [ios, swiftui, sdui, rendering, style-application]
dependencies: []
---

# FooterTabItemView VStack size-clobber

## Resolution

Fixed in PR #17 (round-3 follow-up). Added `JasonStyle.withoutSize()` helper
and used it in `FooterTabItemView` to build a `cellStyle` that drops
width/height before applying `JasonStyleModifier` to the outer `VStack`.
Sizing still flows through `iconWidth`/`iconHeight` to the icon frame as
intended by Jasonpedia fixtures.

Severity escalated from P3 to P2 after gemini round-3 pointed out real
Jasonpedia fixtures (`"height": "21"`) actively clipped captions.

## Problem (original)

`FooterTabItemView` applied `JasonStyleModifier(style: item.style, ...)` to
the outer VStack holding icon + badge + caption. `JasonStyleModifier.applySize`
reads `style.width`/`style.height` → `.frame(width:, height:)`, so tab items
with `"height": "21"` capped the entire cell height and clipped the caption.

Intended semantic: in the tab-item shape, `width`/`height` size the icon (see
Jasonpedia `view/footer/tabs.json`); all other style properties (padding,
opacity, color, background) apply to the cell.

## Approach

Split style application:

- Icon: `iconWidth`/`iconHeight` from `resolvedStyle()` (unchanged from round 2)
- Cell: `resolved.withoutSize()` passed to `JasonStyleModifier` with empty
  `headStyles` and nil `className` (resolution already done upstream)

The `withoutSize()` helper lives on `JasonStyle` next to `merging()` since it
is a simple, reusable operation on the style value type.

## Test coverage

`StyleModifierTests`:

- `testWithoutSizeClearsWidthAndHeight` — verifies width/height nil after strip,
  non-sizing properties preserved
- `testWithoutSizeIsNonMutating` — verifies the helper returns a copy

## Notes

Source: PR #17, gemini-code-assist round-3 feedback (2026-04-18).
