---
id: 031
priority: P3
status: ready
category: nice-to-have
related_pr: "#20"
related_comments:
  - https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/pull/20#discussion_r3106783289
created: 2026-04-19
---

# Investigate ZStack NavigationStack title/toolbar collision across tabs

## Context

`JasonetteTabShell` hosts each tab as a separate `NavigationStack` inside a
`ZStack`. Gemini flagged that when multiple `NavigationStack`s are siblings in
a `ZStack`, SwiftUI's parent-container navigation state propagation (titles,
toolbars) can be unpredictable — the last-mounted / last-in-ForEach stack may
override the visible tab's chrome.

In our implementation this is partially mitigated because:

- Hidden tabs use `.opacity(0) + .allowsHitTesting(false) + .accessibilityHidden(true)`
- Lazy mount (`mounted: Set<TabID>`) means only selected-at-least-once tabs
  are actually realized, so the number of competing stacks is bounded
- Each `JasonetteNavigationView` owns its own `NavigationStack`, so the
  inline toolbar is scoped to that tab's push path

But it is still speculative until observed. If we see title/toolbar flicker
or override on tab switches, the textbook fix is to reorder the `ForEach` so
the selected tab is always last in the ZStack.

## Task

1. Exercise tab switching with multiple tabs that each have a non-trivial
   navigation chrome (title, leading/trailing bar items, large-title behavior,
   pushed detail pages). Confirm the active tab's chrome is correct at
   t = 0 and after switch.
2. If we see override/flicker, switch `ForEach(shell.selectableTabs)` to
   render selected-last. A shell-level change (not a TabShellState change)
   since ordering is a view concern.
3. Add a snapshot or UI test that asserts the visible tab's title survives
   a tab switch.

## Out of scope

- Changing `TabShellState`'s stored order. `selectableTabs` is the authored
  order for the bar; only the view's ZStack rendering order should flip.

## Notes

This is a P3 "nice to have" because no real-world symptom has been reported
yet. Priority jumps to P2 if a customer-facing title/toolbar regression
surfaces.
