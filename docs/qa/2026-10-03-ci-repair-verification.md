# CI repair verification — 2026-10-03

Status: local gates and xhigh review passed; exact-head CI pending.

Workflow: [canonical plan](../plans/2026-10-03-ci-repair-workflow.md).
Contract: [todo110](../../todos/110-fix-ci-ios-actor-isolation-and-markdown-lint.md).
GPT-6.1 Sol high planner/implementer and independent xhigh reviewer; root owns
all tests, builds, Git and CI observation. Host builds are serial with two jobs.

## Red evidence and diagnosis

[CI37097813025](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/37097813025)
failed the iOS package Build step at `6d7ae8f`, on macos14-arm64 image
20260831.0302.1; Test was skipped after compilation failure. The local
Xcode26.2 build/tests had passed. The CI compiler reported nonisolated HTML
helpers invoking the isolated WebKit initializer/property and a nonisolated
horizontal helper invoking ComponentView. Native lifecycle isolation did not
extend to these helper methods under that SDK. Log:
`/private/tmp/jasonette-ci-2026-10-03-ios-failure.log`.

[CI37097836328](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/37097836328)
failed Markdown lint at `5ade934`: exactly one MD012 error, an extra blank line
in the remaining-backlog workflow. This documentation-only run skipped iOS;
it cannot prove the compiler issue is fixed. Xcode Cloud archive and Pages
completed successfully for5ade934.

## Repair

Explicit MainActor isolation on HTMLWebView, its Coordinator, and LayoutView
covers native creation/update, binding mutations, delegate callbacks and view
helpers. Height constants and numeric sanitation are nonisolated pure helpers.
The existing JavaScript completion still applies state through its MainActor
Task. Rendering, hit routing, measured/fixed sizing, and numerical layouts have
no behavioral edits. No compiler-check suppression, runner upgrade, test skip,
package-platform change, SDK or capability change is introduced.

The extra documentation blank is removed. The existing macos14 CI job now logs
Xcode/Swift versions before building, preserving its runner and triggers.

## Local gates

Host macOS26.2, Xcode26.2 build17C52. From `JASONETTE-iOS/JasonetteApp`:

| Gate | Result | Log under `/private/tmp/` |
| --- | --- | --- |
| `swift build --jobs 2` | Success; all package product targets compile | `jasonette-ci-2026-10-03-local-build.log` |
| `swift test --jobs 2 --filter 'HTMLInteractionTests\|HTMLBodyBackgroundTests\|LayoutViewTests'` | 28 passed, zero failures | `jasonette-ci-2026-10-03-local-focused.log` |
| `swift test --jobs 2 --quiet` | 679 passed, zero failures at19:30:13UTC | `jasonette-ci-2026-10-03-local-full.log` |
| Repository `npm run lint:md` | 240 files, zero errors | `jasonette-ci-2026-10-03-markdown-final-source.log` |

Existing behavioral regressions were retained; source-string or annotation-only
tests were not added. The actual failing CI compiler is the compatibility red
boundary and the exact repair-head build/test result is the required green gate.
Previous106–108 native evidence remains applicable because behavior is unchanged.

## Independent review

Fresh GPT-6.1 Sol xhigh reviewer `ci110_review_sol61` reported no concrete
findings in the scoped source diff or root diagnostic/Markdown commit6a297a3.
It verified UI callers and tests already operate on MainActor, pure height
helpers, callback state handoff, unchanged same-source interaction/sizing
updates, fixed/viewport sizing, and platform guards. It ran no tests/builds.
The exact old runner image manifest lists Xcode15.4 as its default with macOS14.5
SDK; the new CI diagnostic step will report the actual selected toolchain.

## Remaining gates

Exact repair-head GitHub Actions iOS Build AND
Test plus lint success, Xcode Cloud status observation, then completion records.
