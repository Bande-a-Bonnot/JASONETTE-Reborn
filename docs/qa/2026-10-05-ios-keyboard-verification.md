# iOS keyboard Done verification — 2026-10-05

Status: complete. Reviewed repair pushed; local/native and exact-source remote gates pass.

Contract: [todo 109](../../todos/109-complete-p3-ios-duplicate-keyboard-done-controls.md).
Workflow: [canonical plan](../plans/2026-10-02-ios-todo-109-workflow.md).
GPT-6.1 Sol high planned and implemented; independent Sol xhigh reviewed both
changes. Root ran serial host gates, native QA and Git. No worker launched a
build, device command or further agent. One host build lease, two jobs.

## Behavioral red and reviewed repair

The [public baseline](artifacts/2026-10-02-ios-backlog/textfield-final-dark-focused.png)
shows three system Done controls, separate from authored document buttons.
The [mixed baseline](artifacts/2026-10-02-ios-backlog/appearance-final-dark-toolbar.png)
shows six with edge clipping. Root inspected native evidence before implementation.

Source `27d9908984785b08de1f6995af503a2b245434b1` installs one toolbar on each
document. A stable UUIDv7 owner flows through the environment; concrete plain,
secure, textarea and structural footer inputs publish it with focused values.
Only the focused document contributes Done. UIKit dismissal, field bindings,
submit actions and accent foreground remain. Independent xhigh review found
no concrete issue. An equality-only test would miss toolbar aggregation and
focus propagation, so native count/lifecycle checks are the regression gate.

Native QA then demonstrated a separate lifecycle failure: actual Inputs → Other
tab selection changed the title while retaining the hidden field's keyboard.
The [red capture](artifacts/2026-10-05-ios-keyboard/tab-switch-stale-keyboard.png)
proves the tab changed without another field being focused. After a reviewed
scope amendment, source `9122a7a6d2ed7fc2d6ce001ec0d2c64de9c8abb8` adds iOS-only
responder dismissal to the central selected-tab observer. Independent xhigh
follow-up review is clean. No toolbar/tab-bar layout overhaul is included.

## Build and test gates

- Focused Swift suite: **105 passed, zero failures**, 11:06:03 UTC on source
  `27d9908`. Log: `/private/tmp/jasonette-ios-2026-10-05-focused.log`.
- Full Swift suite: **679 passed, zero failures** on `27d9908`, then **679/679**
  on final source `9122a7a` at 11:51:22 UTC. Final log:
  `/private/tmp/jasonette-ios-2026-10-05-final-full.log`.
- Fresh final Debug iOS simulator build: success, Xcode 26.2, two jobs.
  Log: `/private/tmp/jasonette-ios-2026-10-05-final-build.log`.
  Derived data: `/private/tmp/JasonetteIOSQAFixes`.
  Installed plist `JasonetteGitCommit` matches the full `9122a7a` hash;
  `JasonetteCIWorkflow` is `LocalQA`.

- Final Markdown lint: **242 files, zero errors**. Log:
  `/private/tmp/jasonette-ios-2026-10-05-final-markdown.log`.

## Native acceptance

Retained iPhone 17 Pro simulator, iOS 26.2. Exact UDID, UUIDv7 session, pinned
agent-device 0.21.12 CLI, state path and fixture server are in the plan.
Root inspected the captures below for count, readability and clipping.

| Check | Observed result | Evidence |
|---|---|---|
| Normal Home → View → Component → textfield | One system Done for plain Unicode entry; secure switch retains one, nine characters masked; dismissal preserves values | [plain light](artifacts/2026-10-05-ios-keyboard/public-light-focused.png), [plain dark](artifacts/2026-10-05-ios-keyboard/public-dark-focused.png), [secure](artifacts/2026-10-05-ios-keyboard/public-dark-secure.png) |
| Authored plain Done action | Selected Value alert receives `Keyboard QA 109 🚀 café` | Native action and alert observed on source `27d9908` |
| Tab selection without focusing another input | Inputs → Other removes keyboard/Done; focusing Other adds one; returning Inputs clears both | [tab green](artifacts/2026-10-05-ios-keyboard/tab-final-switch-cleared.png) |
| Normal public textarea path | Home → View → Component → textarea accepts a real line break; one system Done dismisses and preserves both lines; the authored red Done button remains | [focused](artifacts/2026-10-05-ios-keyboard/final-public-textarea.png), [dismissed](artifacts/2026-10-05-ios-keyboard/final-public-textarea-dismissed.png) |
| Numeric keyboard | Entry `109`, one system Done; Done removes keyboard and preserves `109` | [numeric](artifacts/2026-10-05-ios-keyboard/final-numeric-focused.png) |
| Pushed child document | Plain and secure fields each show one Done; secure value has nine masked characters | [child plain](artifacts/2026-10-05-ios-keyboard/final-child-plain.png), [child secure](artifacts/2026-10-05-ios-keyboard/final-child-secure.png) |
| Multiline entry | Real line break in `Line one` / `Line two café`, one Done; values remain after dismissal | [child multiline](artifacts/2026-10-05-ios-keyboard/final-child-multiline.png), [mixed dark multiline](artifacts/2026-10-05-ios-keyboard/final-mixed-dark-multiline.png) |
| Back while child input is focused | Parent returns with keyboard/Done absent and numeric `109` preserved | [Back green](artifacts/2026-10-05-ios-keyboard/final-back-cleared.png) |
| Structural footer | One Done for `Footer109 café`; dismissal preserves text; Send displays the exact value in its authored alert | [footer focus](artifacts/2026-10-05-ios-keyboard/final-mixed-dark-footer.png), [Send alert](artifacts/2026-10-05-ios-keyboard/final-footer-submit.png) |
| System light with mixed authored surfaces | One readable, unclipped Done on dark plain and nested white inputs | [dark surface](artifacts/2026-10-05-ios-keyboard/final-mixed-light-plain.png), [nested white](artifacts/2026-10-05-ios-keyboard/final-mixed-light-nested.png) |
| No input focused | Zero system Done controls; plain, multiline, nested and footer values remain | [dismissed](artifacts/2026-10-05-ios-keyboard/final-mixed-dismissed.png) |

Public textfield captures use `27d9908`; final source only adds tab-selection
dismissal. All tab/numeric/child/mixed and public textarea captures use installed final `9122a7a`.
The existing [mixed appearance fixture](../fixtures/ios-appearance-107/index.json)
and root-authored [lifecycle fixtures](../fixtures/ios-keyboard-109/index.json)
exercise multiple input families and retained documents.

## Automation limitations and recovery

Simulator startup reported migration failure before SpringBoard was confirmed
running. Runner startup/preparation and a later connection loss required retries;
no failed request alone counts as acceptance. Mounted tabs also produced stale
AX targets, so root relaunched the lifecycle fixture before numeric checks.
A secure fill failed because XCTest reported no keyboard focus. Fresh observation
showed the keyboard absent; separate focus, wait and type recovered and verified
masked entry. Successful serial batches checked multiline, footer, Back and
mixed surfaces. Screenshots show actual line breaks even where AX serializes
newline as an escaped value. Native acceptance covers iOS 26.2; iOS 16 API
availability was checked in source review, not on a second simulator.

## Publication and cleanup

Reviewed product source `9122a7a6d2ed7fc2d6ce001ec0d2c64de9c8abb8` is pushed
to main. [Exact-source CI 37311437068](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/37311437068)
passed iOS Build and **679 tests, zero failures** on Xcode 15.4 / Swift 5.10,
plus Markdown lint. Other platform jobs skipped by path filters. Remote log:
`/private/tmp/jasonette-ios-2026-10-05-remote-ci.log`.
The [Xcode Cloud iOS archive](https://appstoreconnect.apple.com/teams/651d66ea-3da7-4265-80ca-d9c56a196a2e/apps/6759856913/ci/builds/4edb8f7d-bee0-487b-988d-e1d8033deb50/action/e889f418-8846-4680-b9fd-4e68b3b7c5e6)
also passed for this exact source.

Normal entry was restored without the fixture launch override. [Home capture](artifacts/2026-10-05-ios-keyboard/final-home-light.png)
shows Jasonpedia with no keyboard or Done toolbar. System appearance verified
light via simctl. Agent-device session closed successfully. Root verified PID
52338's fixture-server command before stopping it. Retained QA simulator
`9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB` verified **Shutdown**. Todo 109 is complete.
