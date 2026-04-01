---
title: "Fix structural rendering gaps in SwiftUI SDUI renderer"
date: 2026-03-31
category: ui-bugs
module: Jasonette iOS Renderer
problem_type: ui_bug
component: frontend_stimulus
symptoms:
  - "Layers rendered sequentially in LazyVStack instead of floating as ZStack overlays"
  - "Body background color parsed but never applied to any view"
  - "Footer input field decoded but never rendered — only tabs branch existed"
  - "Style properties (opacity, border, directional padding, align) parsed but never applied"
  - "~10 Jasonpedia demos showed empty or broken views"
root_cause: logic_error
resolution_type: code_fix
severity: high
tags: [swiftui, sdui, renderer, layers, styling, footer, opacity, border, jasonette, ios]
---

# Fix Structural Rendering Gaps in SwiftUI SDUI Renderer

## Problem

The Jasonette iOS app had 4 structural rendering gaps where JSON data was decoded correctly into the model layer but the SwiftUI rendering code never consumed it. This caused ~10 Jasonpedia demos to show empty, broken, or visually incorrect views. Every gap followed the same anti-pattern: a property existed in `JasonStyle` or a document struct with proper `CodingKeys` and `merging()` support, but no rendering code read it.

## Symptoms

1. **Layers scrolled with content instead of floating.** Static Layers, Dynamic Layers, Background, and $render Templates demos showed action buttons embedded inline in scrollable content rather than pinned at screen edges.
2. **Body backgrounds were absent.** The Background demo showed no colored background. The Templates demo was missing its yellow (`#f8d728`) background.
3. **Footer text input bar was missing.** The Chat Input demo rendered nothing at the bottom. `footerView()` only branched on `footer.tabs`.
4. **Style properties had no visual effect.** Common Styling/opacity demo was blank. Secure TextField had no borders. Directional padding and alignment were ignored.

## What Didn't Work

The existing architecture assumed decoding a property into the model was sufficient. The model-to-view contract was implicit — no compiler error, no test failure, and no runtime warning when a decoded value went unconsumed.

For layers, the initial architecture placed layer views inside `LazyVStack` within `ScrollView`. Layers participated in scroll layout instead of floating above it.

For footer input, the untyped `[String: JasonComponent]?` dictionary forced manual key lookups with no compile-time safety, making it easy to skip the branch entirely.

For borders, SwiftUI's `.stroke()` draws centered on the shape path — half the border width gets clipped outside bounds, making thin borders appear invisible.

## Solution

### Gap 1 — Layers: ZStack overlays with positioning

Added `top`, `left`, `bottom`, `right` positioning fields to `JasonStyle`. Wrapped the outer `VStack` in a `ZStack(alignment: .topLeading)`. Moved layers OUT of the `LazyVStack` into the ZStack as overlay peers. Each layer derives alignment from which positioning properties are set (`bottom` + `right` → `.bottomTrailing`) with padding to push inward from the aligned edge.

Added `.allowsHitTesting(false)` on `Color.clear` spacer to prevent blocking scroll gestures. Default alignment is `.center` when no positioning is specified.

**Key insight:** Padding-based positioning is cleaner than `GeometryReader` + `.position()` in SwiftUI — avoids center-point coordinate system quirks and works across device sizes without manual calculation.

### Gap 2 — Body background: extract and apply

Extract `body?.background?.string`, parse via `Color(css:)`, apply as `.background(color.ignoresSafeArea())`. Used the existing `ifLet` conditional modifier pattern. `.ignoresSafeArea()` extends color behind nav bar and home indicator.

### Gap 3 — Footer input: dedicated structural view

Replaced the untyped `[String: JasonComponent]?` with a typed `JasonFooterInput` struct (`name`, `placeholder`, `left`, `right`). Created `FooterInputView` as a dedicated structural view — not routed through generic `ComponentView` dispatch. When `name` is nil/empty, `TextField` uses `.constant("")` (unbound) to prevent state collisions.

**Key insight:** Footer and header are structural elements with fixed semantics — they anchor to screen edges, contain specific sub-elements, and don't participate in scrollable content flow. Route through purpose-built views, not generic component dispatch.

### Gap 4 — Style properties: four new modifier steps

- `applyOpacity`: `.opacity(min(max(value, 0), 1))` with clamping
- `applyBorder` enhanced: 4-branch pattern using `if let` bindings and `strokeBorder` (not `stroke`) to keep full border width visible
- `applySpacing` enhanced: directional padding overrides uniform (`let left = paddingLeft?.cgFloat ?? uniform`)
- `applyAlignment`: `.frame(maxWidth: .infinity, alignment:)` for left/center/right

**Key insight about borders:** `.stroke()` draws centered on the shape path — half gets clipped outside bounds. `.strokeBorder()` draws entirely inside the shape, keeping the full border width visible.

## Why This Works

Each fix closes the same structural gap — connecting decoded model data to SwiftUI rendering output — but addresses a different subsystem.

**Layers** needed a spatial relationship change. The ZStack overlay means layers exist in a separate compositing plane from scrollable content.

**Body background** needed a single modifier addition with `.ignoresSafeArea()` for full-screen coverage and `ifLet` to avoid the nil-override trap.

**Footer input** needed a typed model and dedicated view. The typed `JasonFooterInput` struct gives compile-time safety the previous dictionary lacked.

**Style properties** needed modifier pipeline extensions. SwiftUI modifiers compose — order matters: padding applies before the border overlay so borders appear outside padded content.

The consistent pattern: the model was already correct, so fixes were purely in the view layer — low-risk and independently testable. Shipped as 4 parallel PRs from isolated git worktrees, 39 new tests total, 335 tests passing post-merge.

## Prevention

1. **Three-place rule for new JSON properties.** When adding a property to the Jasonette model, it must appear in the struct field, `CodingKeys` enum, AND `merging()`. Then verify the rendering code actually READS it.

2. **Use the `ifLet` conditional modifier pattern for all optional style values.** Passing `nil` to `.foregroundColor(nil)` actively overrides parent values. `ifLet` skips the modifier entirely when the value is absent. See: `docs/solutions/build-errors/swiftui-modifier-gotchas.md`.

3. **Render structural elements with dedicated views, not generic dispatch.** Footer and header are fixed-semantics containers — route through `FooterInputView`, not `ComponentView`.

4. **Use `strokeBorder` instead of `stroke` for borders.** `.stroke()` clips half the line width; `.strokeBorder()` draws entirely inside.

5. **Expect mechanical merge conflicts on parallel PRs touching shared files.** `JasonDocument.swift` and `JasonStyleModifier.swift` are convergence points. Changes are additive, so conflicts resolve by including both sets of additions.

## Related Issues

- See also: [swiftui-modifier-gotchas.md](../build-errors/swiftui-modifier-gotchas.md) — the `ifLet` pattern and nil-override trap
- See also: [anycodable-nsjsonserialization-crash.md](../runtime-errors/anycodable-nsjsonserialization-crash.md) — always `.unwrapped` before JSONSerialization in the render pipeline
- See also: [reviving-a-decade-old-cross-platform-project.md](../architecture-patterns/reviving-a-decade-old-cross-platform-project.md) — Section 6 (LazyVStack recycling), Section 17 (parallel PR workflow)
- PRs: #13 (layers), #14 (background), #15 (footer input), #16 (styles)
- Parent plan: `docs/plans/2026-03-28-001-fix-phase-a-renderer-foundations-plan.md`
- Open todos: #019 (extract shared style resolution), #020 (same-axis layer constraints)
