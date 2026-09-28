# iOS QA fixes: styling and horizontal layout

Status: complete (2026-09-28)

## Approved scope

Implement the three-todo starting order approved on 2026-09-28:

1. [105 — component background bounds](../../todos/105-fix-ios-component-background-bounds.md)
2. [103 — fixed-width button labels](../../todos/103-fix-ios-fixed-width-button-label-truncation.md)
3. [104 — horizontal layout distribution](../../todos/104-fix-ios-horizontal-layout-width-distribution.md)

The linked todos and the [exploratory QA report](../qa/2026-09-26-ios-luna-exploratory-qa.md)
are the source of truth for observed behavior and definitions of done. Scope is
the Swift iOS renderer. Other open todos remain separate.

## Agent workflow

- A `gpt-6-sol` high planner reads this file and the linked todos, researches
  the current code and tests, and adds a concrete implementation and verification
  plan below before product edits begin.
- One `gpt-6-luna` xhigh implementer works through the three todos in the
  approved order, using focused TDD and atomic product/test commits. The primary
  agent owns final simulator evidence and updates todo statuses after each
  definition of done is satisfied.
- The same `gpt-6-sol` high agent performs a final review of the diff and test
  evidence. The implementer addresses confirmed defects, with another focused
  review only if needed.
- Reuse these agents and avoid parallel work on the same files to limit model
  usage and merge overhead.

## Guardrails

- Preserve the unrelated existing `AGENTS.md`, `CLAUDE.md`, and July arbiter
  working-tree changes.
- Follow the repository's SwiftUI style and `JasonStyle` Three-Place Rule.
- Verify focused tests as each slice lands, then run the full iOS Swift package
  test suite. Capture simulator visual evidence for the authored examples when
  the simulator is available. Treat visual verification as a real completion
  gate for these rendering bugs.
- Update `docs/HANDOFF.md` at the end. Do not push or deploy as part of this
  implementation pass.

## Sol implementation plan

### Baseline and boundaries

- Read the three todos and their linked screenshots before changing code. The
  parent agent ran elevated `swift test --quiet` from
  `JASONETTE-iOS/JasonetteApp` on 2026-09-28: **612/612 passed**. Run later
  SwiftPM checks with elevated tool access on this host; default-sandbox
  attempts fail during manifest/cache setup (`sandbox-exec`), before tests run.
  Record the exact result of each verification command.
- Limit edits to the iOS component/style/layout path, focused tests, evidence,
  and the three todos. Preserve the separate section-level horizontal scroller
  in `Rendering/JasonetteView.swift`; the row-level `LayoutView` is the path
  causing text to receive unbounded horizontal proposals. Do not bundle todos
  106–108 or a general percentage-width implementation into this pass.
- For each slice, add a behavioral regression check first, confirm it fails for
  the observed reason, make the smallest renderer change, run the focused check,
  and commit that slice. Existing constant/decoder tests alone do not verify
  visible bounds, label layout, or wrapping. Prefer a deterministic hosted
  SwiftUI layout/pixel/geometry assertion where feasible, with simulator
  screenshots as the visual gate.

### 1. Todo 105 — component background bounds

- In `Components/JasonStyleModifier.swift`, separate foreground color from
  background painting. Apply font/foreground to content, then authored padding
  and explicit width/height, then paint the background and clip/overlay the
  rounded border over those **same final bounds**. Keep alignment expansion
  outside this painted/bordered rectangle so `align: center` does not turn a
  150-point tile into a full-row white strip. Check opacity still affects the
  complete styled component and do not pass nil foreground to SwiftUI.
- Add a focused test in `StyleModifierTests.swift` (or a small hosted-view test
  file) that renders a colored parent with a contrasting styled label using
  padding plus fixed width/height. Assert the background covers a point in the
  padding and a point beyond the intrinsic label but inside the fixed frame;
  assert the exterior stays the parent color. Add a rounded-corner/border case
  to catch an overlay tied to intrinsic text bounds. Use the Action fixture to
  check class resolution still supplies `padded` width, height, and background.
- In the final simulator pass, capture Tutorial → Action before opening a
  sheet. The `$util`/`$media` tiles should be white 150×150 rectangles, with
  text readable and borders/corners, where authored, following the tile edges.

### 2. Todo 103 — fixed-width button labels

- Inspect `Components/ButtonComponent.swift` together with `ComponentRegistry.swift`:
  `ButtonComponent` currently pads text by 14 points on both sides before the
  outer `JasonStyleModifier` fixes the width. Feed the **resolved** component
  style into the text-button layout if needed, so class-defined and inline
  widths behave alike. For a fixed-width text button, let the label use the
  available authored width; keep comfortable default padding for unconstrained
  text buttons. Keep the effective tappable area at least 44×44 points, and
  preserve image-button/fallback behavior. Avoid solving this by lowering the
  global default padding or forcing one-line text to overflow a too-small
  authored width.
- Add a focused behavioral test in `ComponentDispatchTests.swift` or a hosted
  view test: the 60-point `Done` text button renders one complete line at the
  fixture's font size and has a 44-point minimum hit region; an unconstrained
  text button retains its default padding/target, and an image button still
  follows its existing path. Verify class-resolved width as well as inline
  width if the implementation branches on width.
- In the final simulator pass, capture the textarea fixture with the full
  `Done` label. Also inspect both textfield fixture buttons: the 50-point-high
  one must not ellipsize, and the one without authored height must not wrap
  `Don`/`e`.

### 3. Todo 104 — horizontal distribution and constrained rows

- Add `distribution` to `JasonStyle` in `Core/JasonDocument.swift` (stored
  property and `CodingKeys`) and to `merging()` in
  `Components/JasonStyleModifier.swift`. In `ComponentRegistry.swift`, pass the
  **resolved** class-plus-inline style into `LayoutView` for both directions;
  the current call passes only inline style, which would drop class-authored
  `distribution`, `spacing`, and alignment. Add decode/merge/override checks in
  `StyleModifierTests.swift` or `JasonDocumentTests.swift`.
- Rework the horizontal branch of `Components/LayoutView.swift` to use the
  parent row's finite proposed width for ordinary fill and `equalsize` rows.
  Account for the row's authored left/right padding and inter-child spacing
  exactly once. For `equalsize`, divide the remaining width evenly among
  flexible children and propose a finite width to each, so long labels wrap.
  Preserve authored numeric child widths; in mixed rows such as the nested
  tweet (48-point avatar + 10-point gap + flexible vertical content), reserve
  fixed widths first and give the remainder to flexible content. Do not use
  unconstrained `.horizontal` `ScrollView` for these rows, and avoid a
  `GeometryReader` that reports unbounded or zero height in a vertical scroll.
  If explicitly oversized content needs scrolling, keep it in a bounded,
  intentional path; the separate horizontal *section* scroller remains as is.
  Existing percent strings return nil from `AnyCodable.cgFloat`, so check that
  this change does not regress their current rendering without silently
  claiming percentage sizing is implemented.
- Add focused layout regression checks for two equal-width long labels at a
  known parent width, including `spacing: 10` and `padding: 15`; assert equal
  finite child widths and increased wrapped height. Add the avatar/flexible
  nested-row case; assert text stays within the parent width and wraps. Include
  a numeric-width/spacing case and a horizontal section scroll smoke check so
  preserved behaviors are visible in test evidence.
- Capture Tutorial → View → Layout → Horizontal Layout and Complex Nested
  Layout. Both paragraph columns should wrap in equal widths; the nested
  second tweet should remain within the row. Check nearby Action tiles and
  textarea/textfield buttons after the layout change, since those are also
  nested in horizontal rows.

### Completion gates

1. Each focused regression check fails before its fix and passes afterward;
   record the focused commands/results with the corresponding atomic commit.
2. The primary agent runs the full Swift package suite and a fresh Debug iOS
   Simulator build from the final source. Use the retained iPhone 17 Pro
   simulator when available; install that fresh build before taking final
   screenshots. Record build SHA, device/OS, commands, and evidence paths. A
   package test pass alone does not close these visual bugs.
3. Review the final diff for style modifier ordering, 44-point button hit
   target, finite row proposals, preserved authored widths/spacing, and the
   section scroller boundary. Complete each todo only after its tests and
   required screenshot pass; update `docs/HANDOFF.md` with exact evidence.

### Sol review follow-up (2026-09-28)

The first Sol-high review found one concrete overflow regression in todo 104:
two fixed 200-point children in a finite 300-point row make the custom layout
wider than the viewport, but the old row-level scroll view is gone. Add a
bounded, intentional overflow path so the full authored content remains
reachable while ordinary `fill`/`equalsize` rows still receive finite widths.
Add a focused regression for that oversized row and recheck the separate
horizontal section scroller. Commit this correction separately.

The review also found that current unit tests exercise style decoding and width
arithmetic without proving final rendered pixels or text wrapping. The macOS
hosted pixel-test attempts hung at XCTest process exit and were removed. The
primary agent must use fresh iOS Simulator screenshots of Action tiles,
textarea/textfield buttons, horizontal columns, and the nested tweet as the
behavioral rendering gate; record any additional focused pixel/geometry checks
that can run reliably. Do not mark the todos complete on unit checks alone.

### Second Sol review follow-up (2026-09-28)

The first overflow repair used `ViewThatFits` to choose between the finite row
and a scroll fallback. SwiftUI selects by the child's **ideal** size, so long
flexible labels can trigger the fallback even when they would wrap within the
actual viewport. Remove that selection method. Base overflow choice on the
finite width actually offered to the row, reserving fixed and intrinsic child
widths; keep ordinary flexible rows on the finite layout. The final simulator
pass must show both equal-width paragraph wrapping and a successful swipe to
the second 200-point child in the local 300-point overflow fixture.

### Final verification and review (2026-09-28)

The first measured-width repair at `767bfbf` still let an authored 300-point
row expand to 408 points; a targeted pan did not move it. Luna corrected the
branch to honor the resolved authored viewport in `bd9fc1a`. The same targeted
pan on the fresh final simulator build moved the hidden `RIGHT EDGE` label into
view. The full Swift suite passed 622/622, the Debug simulator build succeeded,
and the Action, textarea, textfield, horizontal, and nested screenshots all
passed visual inspection. A separate simulator pixel check verifies padding,
fixed size, and a rounded border. The existing Sol-high reviewer found no
concrete remaining defect in the final source. Exact evidence and commands are
in [the final QA record](../qa/2026-09-28-ios-rendering-fixes-verification.md).
