# iOS todos 106–108 verification

Status: complete. Date: 2026-10-02.

All three canonical definitions of done passed source review, regression tests,
and actual iOS acceptance. The [workflow](../plans/2026-10-02-ios-remaining-backlog-workflows.md)
used GPT-6.1 Sol xhigh for 106/107 planning and implementation, high for 108,
and independent xhigh source reviewers for each. Concrete native follow-ups
used a reused Sol high worker and xhigh reviewer. Root owned every test, build,
commit, and device action; build concurrency was two jobs.

## Regression evidence

| Gate | Result | Host log under `/private/tmp/` |
| --- | --- | --- |
| Baseline full `swift test --jobs 2 --quiet` | 622 passed | Recorded in workflow |
| Red: cancellation + HTML body background | 17 tests, 22 failures including three decode errors | `jasonette-ios-2026-10-02-red-106-108.log` |
| Red: appearance + parser | 39 tests; 36 assertions failed in 14 appearance tests; 25 parser tests passed | `jasonette-ios-2026-10-02-red-107.log` |
| Initial integrated focused | 253 passed | `jasonette-ios-2026-10-02-green-focused-retry.log` |
| Initial integrated full | 673 passed | `jasonette-ios-2026-10-02-green-full.log` |
| HTML bounds/padding focused | 23 passed | `jasonette-ios-2026-10-02-bounds-focused.log` |
| Full after bounds and toolbar corrections | 678 passed | `jasonette-ios-2026-10-02-final-full.log` |
| Action fixture contrast red | One test, 56 expected contrast failures | `jasonette-ios-2026-10-02-action-contrast-red.log` |
| **Final full `swift test --jobs 2 --quiet`** | **679 passed, zero failures** at 21:14:45 UTC | `jasonette-ios-2026-10-02-final-action-green.log` |

The initial focused green compile exposed a new test's raw string delimiter
collision with `#123456`; it was repaired before the successful 253-test run.
This was a test syntax error, not a behavioral red result.

## Source reviews and changes

- **106:** xhigh `ios106_review_sol61` found body-header title precedence;
  repaired with `JasonetteViewModel.navigationTitle` and re-reviewed clean.
  HTML with outer href/action yields native touches to its parent; ordinary
  HTML stays interactive. Legacy object `body.style.background` normalizes into
  the canonical HTML background, which the view and appearance resolver share.
  Native QA then exposed a real bounds defect: 320-point WebKit content centered
  in a 120-point button placed the SVG label inside PDF's activation surface.
  Reused high `ios106_bounds_repair_sol61` repaired resolved exact height.
  Xhigh `ios106_bounds_review_sol61` caught padding overflow; the repair now
  subtracts resolved vertical padding with directional precedence and clamps
  at zero. The follow-up review found no remaining findings.
- **107:** xhigh `ios107_review_sol61` caught tab semantic tint override and
  appearance derived from CSS discarded by an HTML background. Both repaired;
  fresh xhigh `ios107_review_followup_sol61` verified them clean after recovery.
  Native QA caught inherited white foreground on white keyboard Done capsules;
  root scoped an explicit accent foreground to the system button. Xhigh
  follow-up found no findings. The Action fixture authors white body text and
  white/gray child surfaces; xhigh confirmed authored inheritance is correct.
  Eleven explicit black child overrides fix the fixture, with a regression
  covering 28 labels in both schemes. Its xhigh review was clean.
- **108:** xhigh `ios108_review_sol61` found no findings. A private typed
  cancellation marker runs the cancelled action's authored error continuation
  once with incoming payload, then unwinds success arrays, named wrappers,
  utility selection, and timer boundaries. Public boundaries consume it quietly.
  Ordinary failures and media state behavior remain covered by regression tests.

Atomic commits: `1671964` cancellation; `1b293de` HTML/model/title;
`c527894` appearance; `f4e977d` shared integration; `965a375` HTML bounds;
`771c197` keyboard foreground; `246d168` Action fixture correction.

## Final build and provenance

Host macOS 26.2, Xcode 26.2 build 17C52. Retained iPhone 17 Pro / iOS 26.2
simulator `Jasonette-Wander-QA`, UDID `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB`.
Final source: **`246d1688cfb311ce66ba7d284a5b9b3fcb403595`**.

From `JASONETTE-iOS/JasonetteApp`, `mise exec -- tuist generate --no-open`
succeeded; log `jasonette-ios-2026-10-02-tuist.log`. Initial fresh build and
installation succeeded. Tuist reused July provenance metadata, so supported
CLI build-setting overrides refresh the QA artifact without tracked config edits.

Final command:

```sh
xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS \
  -configuration Debug \
  -destination 'id=9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB' \
  -derivedDataPath /private/tmp/JasonetteIOSQAFixes \
  CODE_SIGNING_ALLOWED=NO -jobs 2 \
  JASONETTE_GIT_COMMIT=246d1688cfb311ce66ba7d284a5b9b3fcb403595 \
  JASONETTE_GIT_BRANCH=main JASONETTE_CI_WORKFLOW=LocalQA \
  JASONETTE_BUILD_GENERATED_AT=2026-10-02T21:16:30Z build
```

**BUILD SUCCEEDED**, log `jasonette-ios-2026-10-02-final-build.log`.
`plutil` confirmed `JasonetteGitCommit` exactly matches final source and
`JasonetteCIWorkflow` is `LocalQA`. The app at
`/private/tmp/JasonetteIOSQAFixes/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`
was installed successfully as `com.bande-a-bonnot.jasonette` before final QA.
No new SDK, entitlement, capability, usage string, or portal setup is required.
Existing WebKit and native Photos presentation work on the installed artifact.

## Native acceptance

All captures below are under [the artifact directory](artifacts/2026-10-02-ios-backlog/).
Source is final `246d168` unless explicitly stated. Captures were visually
inspected; accessibility snapshots confirm exact entered text and destinations.

### 106 — HTML row routing and rendering

Normal Home → Tutorial → Web Container, then visible SVG text `@e53` at
(42,637), opened SVG Clock in one tap. Its title and clock face render correctly.
Two captures show the second hand at different positions. Back returned to the
menu. The visible "lots of web containers" text at (125,389) opened the intended
"attaching action to inline web container" document; Back returned again.

- [Aligned menu](artifacts/2026-10-02-ios-backlog/web-container-final.png)
- [Clock A](artifacts/2026-10-02-ios-backlog/svg-clock-final-a.png),
  [Clock B](artifacts/2026-10-02-ios-backlog/svg-clock-final-b.png)
- [Second destination](artifacts/2026-10-02-ios-backlog/lots-web-containers-final.png)
- [Inline and URL DOM buttons after tapping](artifacts/2026-10-02-ios-backlog/html-dom-clicked.png)
  show "Inline HTML clicked" and "URL HTML clicked" on the localhost fixture.
  The internal anchor was tapped as an additional smoke check; its scroll result
  was not separately asserted.

Earlier f4e977d [menu](artifacts/2026-10-02-ios-backlog/web-container-tap.png) and
[PDF destination](artifacts/2026-10-02-ios-backlog/pdf-destination.png) record
why the bounds repair was necessary. `/private/tmp/jasonette-ios-menu-106.json`
showed SVG text y508–566 versus its button y614–734, inside PDF y490–610.
The final check used visible text, rather than a parent-button workaround.

### 107 — appearance, focus, values, and authored colors

Final normal Home → View → Component → textfield navigation passed. Light/dark
empty captures preserve readable heading, prompts, white fields, authored blue
Done buttons, and the authored black border. Entered `Contrast QA 42 🚀 café`
is readable while focused in both schemes. The authored Done action's snapshot
reported "Selected Value, Contrast QA 42 🚀 café" unchanged.

- [Light empty](artifacts/2026-10-02-ios-backlog/textfield-final-light-empty.png),
  [dark empty](artifacts/2026-10-02-ios-backlog/textfield-final-dark-empty.png)
- [Light focused](artifacts/2026-10-02-ios-backlog/textfield-final-light-focused.png),
  [dark focused](artifacts/2026-10-02-ios-backlog/textfield-final-dark-focused.png)
- [Mixed surfaces light](artifacts/2026-10-02-ios-backlog/appearance-final-light-empty.png),
  [dark](artifacts/2026-10-02-ios-backlog/appearance-final-dark-empty.png)
  retain authored #123456 and red text, nested white/dark class surfaces,
  transparent/translucent fills, and explicit white textarea.
- [Dark entered input and repaired toolbar](artifacts/2026-10-02-ios-backlog/appearance-final-dark-toolbar.png),
  [secure masking](artifacts/2026-10-02-ios-backlog/appearance-final-dark-secure.png),
  [Done dismissal](artifacts/2026-10-02-ios-backlog/appearance-final-dark-dismissed.png).
- [Tab Home selected](artifacts/2026-10-02-ios-backlog/tabs-final-home.png),
  [Detail selected](artifacts/2026-10-02-ios-backlog/tabs-final-detail.png)
  show accent selection moving while inactive icon/caption tint stays gray.
- Corrected repository Action JSON was copied temporarily into the localhost
  fixture directory and verified byte-for-byte with `cmp` before launch.
  [Light](artifacts/2026-10-02-ios-backlog/action-final-light.png) and
  [dark](artifacts/2026-10-02-ios-backlog/action-final-dark.png) show readable
  white tiles and gray headers. The temporary copy was removed after QA.

On f4e977d (same textarea/footer implementation), normal Home → View → Component
→ textarea accepted two lines `Line 1 café 🚀` / `Line 2 QA 107`. Both focused
[light](artifacts/2026-10-02-ios-backlog/textarea-light-focused.png) and
[dark](artifacts/2026-10-02-ios-backlog/textarea-dark-focused.png) remain readable
on authored white; Done received the exact multiline banner value and keyboard
[toolbar dismissal](artifacts/2026-10-02-ios-backlog/textarea-dark-dismissed.png)
worked. The mixed dark textarea accepted readable entered text. Footer entry
[remained readable](artifacts/2026-10-02-ios-backlog/appearance-dark-footer.png)
and Send produced the exact [Footer QA107 alert](artifacts/2026-10-02-ios-backlog/appearance-footer-submit.png).
Public secure input also masked synthetic entry correctly before the final
bounds/toolbar build; final dark secure capture above independently confirms it.

### 108 — native cancellation

On f4e977d (108 source unchanged in final build), normal Home → Action → media
picker opened [native Photos](artifacts/2026-10-02-ios-backlog/picker-open.png).
The native top-left close button returned quietly twice: [first](artifacts/2026-10-02-ios-backlog/picker-cancel-first.png)
and [second](artifacts/2026-10-02-ios-backlog/picker-cancel-second.png). No generic
failure alert or success/share sheet followed either cancellation.
The local authored-error fixture opened Photos; cancellation showed
[Cancelled by author](artifacts/2026-10-02-ios-backlog/picker-authored-error.png)
once. OK returned to the [fixture](artifacts/2026-10-02-ios-backlog/picker-authored-dismissed.png)
with no second alert or "Unexpected success" branch. Unit coverage proves media
state is preserved and genuine failures retain feedback; real camera permission
and hardware capture were not exercised in this cancellation-focused pass.

## Automation, cleanup, and remaining follow-up

Pinned unmodified agent-device 0.21.12:
`/private/tmp/jasonette-device-20261002/node_modules/.bin/agent-device`.
State directory `/private/tmp/jasonette-device-state-20261002`, UUIDv7 session
`01a0fddd-2485-7115-aabe-f3a66cfa22ce`. Every call used explicit platform/UDID,
state and session arguments with elevated host access. All builds were serial.
Initial runner preparation needed a longer cached retry; daemon recovery and
one secure-entry XCTest restart interrupted automation, then recovered.
An attempted empty replacement of Unicode textarea content failed tool text
verification; it was not counted as acceptance or a product defect.

The simulator was restored to light appearance and normal Home before
[final capture](artifacts/2026-10-02-ios-backlog/home-final-restored-light.png).
The interaction session closed, the owned localhost fixture server PID 66767
was identified and stopped, and the retained QA simulator shut down successfully.
Unrelated AGENTS.md/CLAUDE.md and historical arbiter changes were preserved.
No remote push, merge, or publication was performed in this workflow.

The corrected Action JSON remains local until publication; the unchanged public
URL still inherits its old authored white foreground on white tiles. A separate
preexisting multiple-input keyboard-toolbar issue is tracked in
[todo 109](../../todos/109-fix-ios-duplicate-keyboard-done-controls.md).
These checks are scoped acceptance for 106–108, not exhaustive whole-app QA.
