# iOS Exploratory QA — 2026-09-26

## Status: complete

This is an in-app exploration of the installed Debug build, not fixture entry
launches. The pass covered all five Tutorial categories, input, navigation,
native actions, dark appearance, and return to Home in light appearance. No
product code has been changed.

Luna performed the device exploration; the primary agent reviewed screenshots,
cross-checked fixtures/source, and created the follow-up todos. This was a
sampled exploratory pass, not exhaustive coverage of every demo.

## Follow-up summary

| Priority | Finding | Todo |
| --- | --- | --- |
| P2 | Horizontal paragraphs do not wrap into their authored columns | [104](../../todos/104-fix-ios-horizontal-layout-width-distribution.md) |
| P2 | Action tile backgrounds cover only text, not the authored tile bounds | [105](../../todos/105-fix-ios-component-background-bounds.md) |
| P2 | Tapping the tested Web Container SVG row does not navigate | [106](../../todos/106-fix-ios-html-row-href-navigation.md) |
| P2 | Default text/placeholder contrast breaks in dark appearance | [107](../../todos/107-fix-ios-default-text-contrast-in-dark-appearance.md) |
| P3 | Ordinary photo-picker cancellation shows a generic failure alert (UX proposal) | [108](../../todos/108-improve-ios-media-picker-cancel-feedback.md) |
| P3, existing | Narrow Done buttons truncate or wrap | [103, updated evidence](../../todos/103-fix-ios-fixed-width-button-label-truncation.md) |

## Environment

- App: `com.bande-a-bonnot.jasonette`, Debug build from `2255ed4`
- Device: iPhone 17 Pro, iOS 26.2, UDID
  `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB` (`Jasonette-Wander-QA`)
- CLI: pinned `agent-device` 0.21.12
- Session: `01a0dd3a-1ea6-74d5-a278-cce91b1103b6`
- State directory: `/private/tmp/jasonette-qa-01a0dd3a-1ea6-74d5-a278-cce91b1103b6`
- Source check: no iOS changes after build commit `2255ed4` at exploration start.
- Evidence directory: `artifacts/2026-09-26-ios-luna-exploratory-qa/`

Successful exploration used the pinned CLI, the session and state directory
above, the UDID, and escalated simulator access. The first command accidentally used
the default user daemon and failed before UI access. A first correct snapshot
showed Home, but a subsequent non-escalated screenshot cleared stale daemon
metadata; the app was reattached without relaunch, and one bounded runner
prepare then succeeded. Home and all following routes were reached in-app.

## Journey log

| Route / action | Outcome | Evidence |
| --- | --- | --- |
| Home baseline | **PASS**; Tutorial (Core, View, Action, Template, Web Container) and Showcase links visible | [home-baseline.png](artifacts/2026-09-26-ios-luna-exploratory-qa/home-baseline.png) |
| Tutorial → Core | **PASS**; `$href`, `$render`, `$snapshot` visible | [core-index.png](artifacts/2026-09-26-ios-luna-exploratory-qa/core-index.png) |
| Core → `$href` | **PASS**; six href examples visible | [core-href.png](artifacts/2026-09-26-ios-luna-exploratory-qa/core-href.png) |
| `$href` → Push transition to another Jason View | **PASS as authored self-link**; identical href menu pushed; back label changed from Core to Jasonette Href; app back returned to the menu | [href-push-attempt.png](artifacts/2026-09-26-ios-luna-exploratory-qa/href-push-attempt.png), [href-push-reproduced.png](artifacts/2026-09-26-ios-luna-exploratory-qa/href-push-reproduced.png) |
| `$href` → Push transition with tabs | **PASS**; three tabs presented; selecting Tab 2 and Tab 3 moved the selected underline; app back returned through the stack | [core-href-tabs-1.png](artifacts/2026-09-26-ios-luna-exploratory-qa/core-href-tabs-1.png), [core-href-tabs-2.png](artifacts/2026-09-26-ios-luna-exploratory-qa/core-href-tabs-2.png) |
| Tutorial → View → Layout → Vertical Layout | **PASS**; text wrapped and both blocks fit; spacer visible | [view-index.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-index.png), [view-layout-vertical.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-vertical.png) |
| Tutorial → View → Layout → Horizontal Layout | **ISSUE**; long rows visibly clip to one line; right and down scroll attempts showed no change | [view-layout-horizontal-top.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-top.png), [view-layout-horizontal-after-right.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-after-right.png), [view-layout-horizontal-after-down.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-after-down.png) |
| Tutorial → View → Layout → Complex Nested Layout | **PARTIAL**; image/post content loaded; second text row clips; scrolling reveals embedded profile imagery under translucent navigation chrome; no separate broken control verified | [view-layout-nested-top.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-nested-top.png), [view-layout-nested-after-scroll.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-nested-after-scroll.png), [view-layout-nested-overlay-repeat.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-nested-overlay-repeat.png) |
| Tutorial → View → Component → textfield | **PASS for input**; ordinary field accepted `Luna QA 42 🚀 café`; secure field masks synthetic `sëcret🔐`; keyboard stayed below the focused row and app Done control. Done action announced the exact ordinary value via transient UI (observed in settled AX diff; screenshot taken after the transient disappeared). | [component-textfield-initial.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-initial.png), [component-textfield-unicode-keyboard.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-unicode-keyboard.png), [component-textfield-unicode-done.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-unicode-done.png) |
| Tutorial → View → Component → textarea | **PASS for input**; multiline Unicode and a blank line were preserved in the text view and in the Done result | [component-textarea-initial.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textarea-initial.png), [component-textarea-multiline-keyboard.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textarea-multiline-keyboard.png) |
| Tutorial → Action → `$util.toast` | **PASS**; settled accessibility diff reported `I'm a toast. I display a simple text.` | Luna's observed AX result, quoted at left; no screenshot of the transient |
| Tutorial → Action → `$util.alert (basic)` | **PASS**; native Basic Alert title/body rendered; tapping OK returned to the action index | [action-alert.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-alert.png) |
| Tutorial → Action → `$media.picker + $util.share (photo)` → Cancel | **P3 UX concern**; native picker appeared; Cancel showed a generic app error alert instead of quietly returning | [action-photo-picker.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker.png), [action-photo-picker-cancel-error.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker-cancel-error.png) |
| Tutorial → Action → utility examples | **PARTIAL**; toast message appeared in settled accessibility diff; alert presented and dismissed; photo picker opened and cancellation alert reproduced | [action-index-top.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-index-top.png), [action-alert.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-alert.png), [action-photo-picker.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker.png), [action-photo-picker-cancel-error.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker-cancel-error.png) |
| Tutorial → Template → Inline Data | **PASS**; inline template rendered its image/avatar and `ethan` value; index intro text appears clipped at the right edge in its row | [template-index.png](artifacts/2026-09-26-ios-luna-exploratory-qa/template-index.png), [template-inline-data.png](artifacts/2026-09-26-ios-luna-exploratory-qa/template-inline-data.png) |
| Tutorial → Web Container | **PARTIAL / ISSUE**; animated HTML menu rendered and scrolled; two visible SVG-row taps and one parent-control attempt left the menu unchanged | [webcontainer-index.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-index.png), [webcontainer-scrolled.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-scrolled.png), [webcontainer-svg-after-tap.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-svg-after-tap.png), [webcontainer-svg-parent-button.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-svg-parent-button.png) |
| Home → dark appearance → textfield → light appearance → Home | **ISSUE**; dark mode makes the `textfield` heading nearly white on authored light gray and placeholder text very dark on black fields; light mode restored and captured on Home | [home-dark-appearance.png](artifacts/2026-09-26-ios-luna-exploratory-qa/home-dark-appearance.png), [component-textfield-dark.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-dark.png), [component-textfield-restored-light.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-restored-light.png), [home-restored-light.png](artifacts/2026-09-26-ios-luna-exploratory-qa/home-restored-light.png) |
| Restored-light textfield → submit empty first field | **PASS**; result diff showed `Selected Value` with no value and no error | Luna's observed result diff; empty field baseline in [component-textfield-restored-light.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-restored-light.png) |

## Findings

### Horizontal `distribution: equalsize` text is clipped

- Severity: **P2**
- Category: visual / layout compatibility
- Expected: equal-size horizontal child components wrap their text within the
  available column widths, according to the local document contract.
- Observed: in the Horizontal Layout example, each long text row appears as a
  single clipped line (`...is cutt` and `...bile-drenched pe...`). A rightward
  scroll and a downward scroll caused no visible change. The nested layout also
  has a clipped tweet row, which may share the same layout path.
- Repro: open the normal app → Tutorial → View → Layout → Horizontal Layout.
  Inspect the first viewport; then try `agent-device scroll right 0.8 --settle`
  and `agent-device scroll down 0.8 --settle` in the same session.
- Evidence: [view-layout-horizontal-top.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-top.png),
  [view-layout-horizontal-after-right.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-after-right.png),
  [view-layout-horizontal-after-down.png](artifacts/2026-09-26-ios-luna-exploratory-qa/view-layout-horizontal-after-down.png).
- Local contract/source cross-check by the parent agent: the fixture authors
  `distribution: equalsize`; local layout documentation specifies equal-width
  horizontal children should fill the row; current `JasonStyle` omits a
  `distribution` field. This corroborates the runtime clipping. The missing
  remote image icon in the same screen is tracked separately as fixture/network
  behavior, not included in this finding.

### Canceling the photo picker shows an alarming generic error

- Severity: **P3**
- Category: UX / native action cancellation
- Expected: canceling the native picker should stop the share chain without
  implying that the app or user action failed, unless the document provides an
  authored cancellation/error continuation.
- Observed: dismissing Photos with Cancel opened `Action failed` with message
  `Media capture was cancelled.` and an OK button. No image was selected and
  the share chain was not entered.
- Repro: Tutorial → Action → `$media.picker + $util.share (photo)` → tap the
  native Photos Cancel button.
- Evidence: [action-photo-picker.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker.png),
  [action-photo-picker-cancel-error.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker-cancel-error.png).
- Limit: the demo authors a success continuation but no explicit error
  continuation, and the action documentation does not define cancel UX. Treat
  this as a recommendation to suppress the generic alert for ordinary cancel
  while preserving authored error callbacks, not as a proven callback-contract
  violation.

### Action tiles do not paint their authored bounds

- Severity: **P2**
- Category: visual / style bounds
- Expected: the Action demo's `padded` labels request 150×150 white tiles.
- Observed: the un-dimmed screen shows small white patches sized around the
  text, rather than backgrounds filling the authored tile bounds.
- Repro: Tutorial → Action; inspect the first viewport.
- Evidence: [action-index-top.png](artifacts/2026-09-26-ios-luna-exploratory-qa/action-index-top.png).
- Source cross-check: the style modifier applies background before authored
  spacing and size, so the painted background does not expand with those
  dimensions. This is separate from the picker cancellation concern.

### Web Container SVG row does not navigate

- Severity: **P2**
- Category: navigation / embedded HTML interaction
- Expected: tapping the visible SVG menu row should open its nested `svg.json`
  example and allow returning to the menu.
- Observed: two taps on the visible SVG text and one attempt on its parent
  control left the animated menu unchanged. The nested endpoint returned HTTP
  200 from the host and matched the local fixture; simulator request details
  were unavailable because `agent-device network dump 100 summary` failed with
  `xcrun timed out after 4000ms`.
- Repro: Tutorial → Web Container; tap the visible `svg` row twice, then attempt
  the parent control once.
- Evidence: [webcontainer-index.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-index.png), [webcontainer-svg-after-tap.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-svg-after-tap.png),
  [webcontainer-svg-parent-button.png](artifacts/2026-09-26-ios-luna-exploratory-qa/webcontainer-svg-parent-button.png).
- Confidence: the SVG row's navigation failure is reproducible. An interactive
  WKWebView intercepting the outer component tap is a plausible cause, not
  confirmed; this finding is scoped to the tested row.
- Host check: curl returned HTTP 200 for the public
  [SVG document](https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/svg.json)
  and [template dependency](https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/template2.json).
  Both parsed JSON responses matched their local fixtures. This does not prove
  simulator network requests succeeded.

### Textfield defaults have poor contrast in dark appearance

- Severity: **P2**
- Category: visual / contrast
- Expected: labels and placeholder text remain legible when the app is shown
  in dark appearance over fixture-authored backgrounds.
- Observed: the `textfield` heading becomes nearly white on its authored light
  gray background, while placeholder text becomes very dark on black fields.
- Repro: switch simulator appearance to dark, then open Tutorial → View →
  Component → textfield.
- Evidence: [home-dark-appearance.png](artifacts/2026-09-26-ios-luna-exploratory-qa/home-dark-appearance.png), [component-textfield-dark.png](artifacts/2026-09-26-ios-luna-exploratory-qa/component-textfield-dark.png).
- Source cross-check: the fixture authors backgrounds without foreground
  colors; the text field uses system rounded-border/default placeholder
  styling. This is a visual finding only; no contrast ratio was measured.

## Coverage limits and follow-up

- The broad pass reached Core, View, Action, Template, and Web Container from
  Home. It sampled href push/tabs, vertical/horizontal/nested layouts, text
  inputs, alert/toast, photo picker cancellation, inline template data, and an
  animated HTML menu.
- Date picker, media selection success/share, geo actions, Showcase external
  links, rotation, long-input stress, form alerts, and other individual examples
  remain untested. The native photo picker was canceled before selecting a
  photo or entering share. Empty submission, ordinary Unicode input, secure
  masking, and multiline/blank-line textarea input were exercised.
- Page-level scroll attempts did not visibly change the horizontal layout
  clipping; this does not establish that every nested/inner scroll path was
  exhausted. The animated Web Container menu did not settle; inspection used
  immediate screenshots and taps without treating its animation as a failure.
- Dark appearance was restored to light. The app was returned to Home and
  [home-restored-light.png](artifacts/2026-09-26-ios-luna-exploratory-qa/home-restored-light.png) captured. The simulator remains available for the
  next pass.
- Follow-up todos 104–108 were created after review; existing todo 103 received
  the textfield and textarea Done-button observations. See the summary table.
