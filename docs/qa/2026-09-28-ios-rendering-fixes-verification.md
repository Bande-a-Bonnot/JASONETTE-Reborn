# iOS rendering fixes: final verification

Date: 2026-09-28. Product source: `bd9fc1a`. Device: `Jasonette-Wander-QA`,
iPhone 17 Pro, iOS 26.2 (`9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB`). All final
screenshots below came from a fresh Debug simulator build of that source, not
the previously installed September 26 app.

## Build and tests

- From `JASONETTE-iOS/JasonetteApp`, elevated
  `swift test --jobs 2 --quiet` passed **622 tests, 0 failures** after the final
  layout correction. Baseline before this work was 612/612. The new Action
  fixture test initially failed because its repository-root helper omitted one
  parent directory; this test-only correction is `d968039`, and the subsequent
  full runs passed.
- Elevated `mise exec -- tuist generate --no-open` succeeded. Elevated
  `xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS
  -configuration Debug -destination
  'id=9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB'
  -derivedDataPath /private/tmp/JasonetteIOSQAFixes CODE_SIGNING_ALLOWED=NO
  -jobs 2 build` reported **BUILD SUCCEEDED** after `bd9fc1a`. The resulting
  `Jasonette_iOS.app` was installed with `simctl`.
- The existing Sol high reviewer performed a narrow final source review at
  `bd9fc1a` and found no concrete remaining defect. It did not run the tests
  or simulator; the commands and captures in this report were run by the
  primary agent.

## Visual checks

The Debug app loaded the repository fixtures over a local HTTP server through
`-JasonetteEntryURL`. Static captures use `simctl io screenshot` on the final
installed build.

| Todo | Fixture and final evidence | Observation |
| --- | --- | --- |
| 105 | [Action](artifacts/2026-09-28-ios-rendering-fixes/action.png) | White tile backgrounds span their authored 150-point height and width instead of only the text bounds. |
| 103 | [Textarea](artifacts/2026-09-28-ios-rendering-fixes/textarea.png), [textfield](artifacts/2026-09-28-ios-rendering-fixes/textfield.png) | The 60-point `Done` label is complete in the textarea and in both textfield rows; neither textfield label wraps or ellipsizes. The focused button checks retain the 44-point minimum hit size. |
| 104 | [Horizontal](artifacts/2026-09-28-ios-rendering-fixes/horizontal.png), [nested](artifacts/2026-09-28-ios-rendering-fixes/nested.png) | Both long paragraph columns wrap within equal widths. The second nested tweet stays within the row. |
| 104 | [Overflow before](artifacts/2026-09-28-ios-rendering-fixes/overflow-final-before.png), [after targeted pan](artifacts/2026-09-28-ios-rendering-fixes/overflow-final-after.png) | A 300-point authored row containing two 200-point tiles and an 8-point gap clips the second tile at the viewport edge. `agent-device gesture pan 270 155 -180 0 500` inside the row moves the full `RIGHT EDGE` label into view. A Pillow comparison of the row crop found a nonempty pixel difference. |

For todo 105, the separate [style-bounds fixture](fixtures/ios-style-bounds/index.json)
and [capture](artifacts/2026-09-28-ios-rendering-fixes/style-bounds.png)
exercise padding and explicit size independently, with a rounded border on the
fixed tile. Run
`python3 docs/qa/check-ios-style-bounds.py docs/qa/artifacts/2026-09-28-ios-rendering-fixes/style-bounds.png`
from the repository root with Pillow installed. It passed: **115,725 red fill
pixels** over the fixed tile, **33,688 blue fill pixels** over the padding-only
label, and a **450×300-pixel** green border around the authored 150×100-point
tile at 3× simulator scale. The [checker](check-ios-style-bounds.py) asserts
all three painted bounds and the border's relation to the fill.

The [overflow fixture](fixtures/ios-layout-overflow/index.json) is included so
the last interaction check can be repeated. An earlier build at `767bfbf`
painted the row outside its width but did not move after a targeted pan; its
[before](artifacts/2026-09-28-ios-rendering-fixes/overflow-before.png) and
[after](artifacts/2026-09-28-ios-rendering-fixes/overflow-after-row-pan.png)
captures have identical row pixels. That observed failure drove the final
authored-viewport correction `bd9fc1a`.

This pass checks the listed authored screens and one oversized-row interaction.
It does not claim exhaustive navigation, appearance, or device-size coverage.
