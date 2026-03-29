---
title: "fix: Phase A renderer foundations — layers, background, footer input, styles"
type: fix
status: completed
date: 2026-03-28
origin: docs/plans/2026-03-28-fix-ios-components-actions-audit-plan.md
---

# fix: Phase A renderer foundations

## Overview

Four parallel PRs fixing foundational rendering issues in the iOS SwiftUI renderer. Each is independent and lands on its own branch. Together they unblock ~10 broken Jasonpedia demos.

## Problem Frame

User tested every Jasonpedia demo. Most are broken because of 4 structural gaps in the renderer:
1. Layers rendered sequentially in a VStack instead of as floating overlays
2. Body background parsed but never applied
3. Footer input parsed but never rendered (only tabs render)
4. Style properties parsed but never applied (opacity, border, directional padding, align)

## Requirements Trace

- R1. Layers float above body content with absolute positioning via top/left/bottom/right style properties
- R2. Body background color renders behind all content
- R3. Footer input renders a text input bar with optional left/right action buttons
- R4. All parsed style properties are applied: opacity, border_color, border_width, directional padding
- R5. All existing 298 tests continue to pass
- R6. Each fix ships as a separate PR from its own branch

## Scope Boundaries

- Background images and camera backgrounds are out of scope (color strings only for now)
- Dynamic layer manipulation (resize/move/rotate) is out of scope
- Percentage-based positioning expressions (e.g. "30%-87") are deferred — support numeric and simple string values first
- Footer input is the Jasonette `footer.input` structure only, not a generic chat UI
- `align` and `spacing` are layout-level — only apply `align` as frame alignment on individual components; `spacing` is already handled by LayoutView

## Context & Research

### Relevant Code and Patterns

- `JasonetteView.swift` — main document renderer, uses `ifLet` conditional modifier pattern
- `JasonStyleModifier.swift` — centralized style chain: applyFont → applyColors → applySpacing → applyBorder → applySize
- `JasonDocument.swift` — all model types; `JasonStyle.merging()` must be updated for any new fields
- `ComponentRegistry.swift` (`ComponentView`) — dispatches component type, applies JasonStyleModifier uniformly
- `Color(css:)` — parses hex (#RRGGBB/#RRGGBBAA), rgb(), rgba()
- `StateManager.binding(forKey:default:)` — connects SwiftUI inputs to state (used by TextFieldComponent)
- Test pattern: `makeDocument(_ json:)` helpers, `@MainActor async` tests, no setUp/tearDown

### Institutional Learnings

- **SwiftUI modifier nil trap** (docs/solutions/build-errors/swiftui-modifier-gotchas.md): Passing nil to a modifier actively overrides parent values. Use the existing `ifLet` extension for all optional style applications.
- **`#if os(iOS)` not `#if canImport`** (docs/solutions/build-errors/swift-canImport-vs-os-platform-check.md): For iOS-only APIs in footer input.
- **Structural elements vs component containers** (docs/solutions/architecture-patterns/reviving-a-decade-old-cross-platform-project.md): Footer input is a structural element with fixed semantics, not a generic component dispatch. Render with dedicated logic, not ComponentView.

## Key Technical Decisions

- **Layers use ZStack overlay**: Layers wrap the ScrollView in a ZStack. Each layer is positioned using `.position()` or `.offset()` derived from its style's top/left/bottom/right fields. This matches CSS `position: absolute` semantics from the original Jasonette spec.
- **Positioning fields go on JasonStyle**: Add `top`, `left`, `bottom`, `right` to `JasonStyle` rather than creating a separate positioning model. They are style properties in the JSON spec.
- **Body background is color-only for now**: `body.background` is `AnyCodable?`. Extract `.string` and pass through `Color(css:)`. Image backgrounds need AsyncImage + more complex layout — defer to a follow-up.
- **Footer input uses dedicated rendering**: Not routed through ComponentView. The input structure is `{"textfield": {...}, "left": {...}, "right": {...}}` — a fixed schema, not a type-dispatched component.
- **Opacity goes on JasonStyle as a new field**: Added to model, CodingKeys, and merging(). Applied via `.opacity()` in a new `applyOpacity` step.

## Open Questions

### Resolved During Planning

- **Should layers scroll?** No. Layers are fixed overlays. They sit in a ZStack above the ScrollView, not inside it.
- **Can footer have both tabs and input?** In the original spec they are mutually exclusive. Render whichever is present; if both exist, prefer tabs.
- **Should `align` be applied in JasonStyleModifier?** Yes, as `.frame(maxWidth: .infinity, alignment:)` for left/center/right. This is component-level horizontal alignment, distinct from LayoutView's stack alignment.

### Deferred to Implementation

- Exact GeometryReader usage for percentage-based layer positioning
- Whether `bottom`/`right` positioning needs screen-relative or parent-relative calculation

## Implementation Units

### PR 1: Layers as ZStack overlays — branch `fix/layers-zstack-overlay`

- [ ] **Unit 1.1: Add positioning fields to JasonStyle**

  **Goal:** Model layer positioning properties

  **Requirements:** R1

  **Dependencies:** None

  **Files:**
  - Modify: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/JasonDocument.swift`
  - Test: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/StyleModifierTests.swift`

  **Approach:**
  - Add `top`, `left`, `bottom`, `right` as `AnyCodable?` fields to `JasonStyle`
  - Add CodingKeys entries (they're already snake_case-compatible)
  - Update `merging()` to include the 4 new fields

  **Patterns to follow:** Existing `paddingLeft`/`paddingRight` pattern in JasonStyle

  **Test scenarios:**
  - Happy path: Decode style JSON with `{"top": "10", "left": "20"}` → fields populated
  - Happy path: `merging()` carries forward positioning fields; inline overrides head style
  - Edge case: Positioning fields absent → all nil, merging preserves nil

  **Verification:** `swift test` passes; style with positioning fields decodes and merges correctly

- [ ] **Unit 1.2: Render layers as ZStack overlays**

  **Goal:** Move layers out of LazyVStack, render as positioned overlays

  **Requirements:** R1, R5

  **Dependencies:** Unit 1.1

  **Files:**
  - Modify: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift`
  - Test: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/TemplateRenderTests.swift`

  **Approach:**
  - Wrap the existing `VStack(spacing: 0) { ScrollView { ... } footer }` in a `ZStack`
  - Remove the layers block from inside the LazyVStack
  - Add layers as overlay views in the ZStack, after the main VStack
  - For each layer component, read its `style.top`, `style.left`, `style.bottom`, `style.right`
  - Use a `GeometryReader` + `.position()` to place layers absolutely
  - If no positioning is specified, layer renders centered (default ZStack behavior)
  - Use `.allowsHitTesting(true)` on layers so they receive taps

  **Patterns to follow:** The existing `ifLet` conditional modifier pattern for optional positioning values

  **Test scenarios:**
  - Happy path: Document with layers array → layers decode and appear in renderedRoot.body.layers
  - Happy path: Layer with `style.top: "10"` and `style.left: "20"` → positioned at those offsets
  - Edge case: Layer with no positioning style → renders without crash (centered)
  - Edge case: Document with both sections and layers → sections scroll, layers float above
  - Integration: Layer component with `action` → tapping triggers the action

  **Verification:** Static Layers and $render templates demos show layers floating above content. Layers are tappable.

---

### PR 2: Body background — branch `fix/body-background-color`

- [ ] **Unit 2.1: Apply body background color**

  **Goal:** Render `body.background` as a color behind all body content

  **Requirements:** R2, R5

  **Dependencies:** None

  **Files:**
  - Modify: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift`
  - Test: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/ViewModelTests.swift`

  **Approach:**
  - In `documentBody`, extract background from `body?.background?.string`
  - Parse via `Color(css:)` — reuse existing pattern from header background
  - Apply as `.background(color)` on the outer VStack (or ZStack if layers PR landed first — but this PR should work independently)
  - Use the `ifLet` pattern to avoid the nil-override trap

  **Patterns to follow:** Header background pattern at JasonetteView.swift lines 103-107

  **Test scenarios:**
  - Happy path: Document with `body.background: "#ff0000"` → renderedRoot.body.background contains the color string
  - Happy path: Document with `body.background: "rgb(0,255,0)"` → parses correctly
  - Edge case: No background specified → no background applied, no crash
  - Edge case: Invalid color string → falls through gracefully (no background)

  **Verification:** Background demo shows colored page when `$set` changes the background value. Templates demo shows yellow `#f8d728` background.

---

### PR 3: Footer input — branch `fix/footer-input-rendering`

- [ ] **Unit 3.1: Render footer input bar**

  **Goal:** Render `footer.input` as a text input bar at the bottom of the screen

  **Requirements:** R3, R5

  **Dependencies:** None

  **Files:**
  - Modify: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift`
  - Test: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/ComponentDispatchTests.swift`

  **Approach:**
  - In `footerView`, add an `else if let input = footer.input` branch
  - The Jasonette `footer.input` structure is a dictionary with keys: `"textfield"`, optional `"left"`, optional `"right"`
  - Render as `HStack`: optional left button | TextField | optional right button
  - Left/right are `JasonComponent` — render via `ComponentView` for action/href support
  - TextField: extract `name` and `placeholder` from the textfield component, bind to `StateManager` using `stateManager.binding(forKey:default:)`
  - Apply consistent footer styling: padding, background, top shadow (matching existing tab footer)
  - Guard with `#if os(iOS)` if using any iOS-only APIs

  **Patterns to follow:**
  - Existing `TextFieldComponent` for state binding pattern
  - Existing footer tabs HStack layout and styling
  - Institutional learning: footer is a structural element, not a component dispatch

  **Test scenarios:**
  - Happy path: Footer JSON with `input.textfield` → text field renders with placeholder
  - Happy path: Footer with `input.left` (image button) and `input.right` (text button) → both render flanking the text field
  - Edge case: Footer with only `input.textfield`, no left/right → text field renders full width
  - Edge case: Footer with both `tabs` and `input` → tabs take precedence
  - Integration: Right button with action → tapping triggers the action; `$get.message` contains typed text

  **Verification:** Chat Input demo shows text field at bottom with camera icon (left) and Send button (right). Typing text and tapping Send shows alert with the message.

---

### PR 4: Missing style properties — branch `fix/style-modifier-gaps`

- [ ] **Unit 4.1: Add opacity to JasonStyle model**

  **Goal:** Model the opacity property

  **Requirements:** R4

  **Dependencies:** None

  **Files:**
  - Modify: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/JasonDocument.swift`
  - Test: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/StyleModifierTests.swift`

  **Approach:**
  - Add `opacity: AnyCodable?` to JasonStyle
  - Add to CodingKeys enum
  - Update `merging()` to include opacity

  **Test scenarios:**
  - Happy path: Decode `{"opacity": "0.5"}` → field populated
  - Happy path: merging carries forward opacity; inline overrides

  **Verification:** Opacity field decodes and merges

- [ ] **Unit 4.2: Apply missing style properties in modifier**

  **Goal:** Apply opacity, border (color + width), and directional padding

  **Requirements:** R4, R5

  **Dependencies:** Unit 4.1

  **Files:**
  - Modify: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Components/JasonStyleModifier.swift`
  - Test: `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/StyleModifierTests.swift`

  **Approach:**
  - Add `applyOpacity` step: read `opacity?.cgFloat`, apply via `.opacity()` using `ifLet` pattern
  - Enhance `applyBorder`: if `borderWidth` and `borderColor` are present, add `.overlay(RoundedRectangle(cornerRadius: radius ?? 0).stroke(color, lineWidth: width))` after the existing clipShape
  - Enhance `applySpacing`: check directional padding fields first. If any directional padding is set, apply `.padding(.leading, left)`, `.padding(.trailing, right)`, `.padding(.top, top)`, `.padding(.bottom, bottom)`. If none are set, fall back to uniform padding. Directional padding overrides uniform for that edge.
  - Add `applyAlignment`: if `align` is "center", "left", or "right", apply `.frame(maxWidth: .infinity, alignment:)` to position content
  - Add all new apply steps to the modifier body chain
  - Use `ifLet` / conditional `@ViewBuilder` for all optional properties to avoid the nil-override trap

  **Patterns to follow:**
  - Existing `applyColors` 4-branch pattern for combining optionals
  - `ifLet` extension already available in JasonetteView.swift — will need to make it `internal` or duplicate in JasonStyleModifier.swift (prefer making it package-internal)

  **Test scenarios:**
  - Happy path: Style with `opacity: "0.5"` → opacity applied
  - Happy path: Style with `border_width: "2"` and `border_color: "#000000"` → border stroke rendered
  - Happy path: Style with `padding_left: "10"`, `padding_top: "5"` → directional padding applied
  - Happy path: Style with `align: "center"` → content centered horizontally
  - Edge case: Style with both uniform `padding: "10"` and `padding_left: "20"` → left gets 20, others get 10
  - Edge case: Border color without width → no border rendered (need both)
  - Edge case: Opacity of 0 → fully transparent; opacity of 1 → fully opaque
  - Edge case: No new properties set → identical behavior to current (regression check)

  **Verification:** Common Styling/opacity demo shows components at different transparencies. Secure TextField shows bordered text fields. All 298+ existing tests pass.

## System-Wide Impact

- **File conflicts**: All 4 PRs may touch `JasonetteView.swift` and/or `JasonDocument.swift`. Each works on its own branch; merge conflicts are expected and straightforward (additive changes to different sections).
- **Style merging**: PR 1 and PR 4 both add fields to `JasonStyle.merging()`. Second merge will need to incorporate both sets of new fields.
- **ifLet extension**: Currently `private` in JasonetteView.swift. PR 4 needs it in JasonStyleModifier.swift. Options: make it `internal`, move to a shared file, or duplicate (simplest for parallel work — deduplicate on merge).
- **Test count**: Each PR adds tests. Final merged count will be 298 + new tests.

## Risks & Dependencies

- **Merge conflicts are expected** between the 4 PRs since they touch overlapping files. All changes are additive (new fields, new view branches, new modifier steps) so conflicts should be mechanical.
- **Layer positioning without GeometryReader**: Simple offset-based positioning works for numeric values. Percentage-based values from some demos (e.g. "30%-87") will need a follow-up.
- **Footer input model may need adjustment**: `input` is typed as `[String: JasonComponent]?` — a dictionary. If the Jasonpedia JSON uses a different structure (e.g. with `"left"` as a nested object), decoding should work since JasonComponent is flexible. Verify during implementation.

## Sources & References

- **Origin document:** [Phase A audit plan](docs/plans/2026-03-28-fix-ios-components-actions-audit-plan.md)
- Related code: `JasonetteView.swift`, `JasonStyleModifier.swift`, `JasonDocument.swift`
- Learnings: `docs/solutions/build-errors/swiftui-modifier-gotchas.md`, `docs/solutions/architecture-patterns/reviving-a-decade-old-cross-platform-project.md`
