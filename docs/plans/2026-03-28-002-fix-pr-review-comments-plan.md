---
title: "fix: Address PR review comments on Phase A PRs"
type: fix
status: completed
date: 2026-03-28
origin: docs/plans/2026-03-28-001-fix-phase-a-renderer-foundations-plan.md
---

# fix: Address PR review comments on Phase A PRs

## Overview

Triage and address review comments from Gemini, Copilot, and CodeRabbit on PRs #13-#16.

## Triage

### P1 — Must fix

1. **PR #13: Color.clear blocks hit-testing on ScrollView** (Copilot)
   - `Color.clear` in the layer ZStack fills the screen and intercepts taps/scrolls
   - Fix: Add `.allowsHitTesting(false)` on the `Color.clear` spacer

2. **PR #13: Default layer alignment should be center, not topLeading** (Copilot)
   - When no positioning fields are set, layer pins to top-left instead of center
   - Fix: Return `.center` from `layerAlignment` when no positioning is specified

3. **PR #15: Empty name binding causes state collisions** (Gemini + Copilot)
   - `input.name ?? ""` binds to key `""` in StateManager if name is nil
   - Fix: Guard with a fallback unique key or skip TextField rendering when name is missing

### P2 — Should fix

4. **PR #16: Force unwraps in applyBorder** (Copilot)
   - Use `if let` binding instead of `!` after nil checks

5. **PR #16: stroke vs strokeBorder** (Copilot)
   - `stroke` draws centered on path, half gets clipped. Use `strokeBorder` to keep full width visible

6. **PR #16: Opacity not clamped** (Copilot)
   - Clamp to 0...1 before applying

7. **PR #14: Add loadState assertions** (Copilot)
   - Add `XCTAssertEqual(vm.loadState, .loaded)` before checking renderedRoot in background tests

8. **PR #15: Remove unused headStyles parameter** (Copilot)
   - Dead code in FooterInputView

### Nits — Reply with rationale, don't fix

9. **PR #13: resolveLayerStyle duplication** — Known, planned dedup in follow-up
10. **PR #13: Same-axis constraints** (CodeRabbit) — Document as current limitation
11. **PR #14: Parameterized tests** (Gemini) — Existing pattern uses individual tests
12. **PR #15: try! in test helper** (Gemini) — Matches all 17 existing test files
13. **PR #15: AsyncImage fallback** (Copilot) — Minor UX, defer

## Implementation Units

- [ ] **Fix PR #13**: Color.clear hit-testing + default center alignment
- [ ] **Fix PR #15**: Guard empty name + remove unused headStyles
- [ ] **Fix PR #16**: if-let binding, strokeBorder, clamp opacity
- [ ] **Fix PR #14**: Add loadState assertions in tests
- [ ] **Reply to all comments** on all 4 PRs with rationale
