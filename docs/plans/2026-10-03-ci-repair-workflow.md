# Restore GitHub Actions iOS and documentation checks

Status: active. Canonical todo: [110](../../todos/110-fix-ci-ios-actor-isolation-and-markdown-lint.md).
User authorized this workflow after checking the pushed iOS changes.

## Models and ownership

GPT-6.1 Sol high plans and implements the compiler repair; an independent
GPT-6.1 Sol xhigh reviewer checks it. Root owns tests, Git, CI observation,
Markdown correction, workflow edits, evidence, and handoff. Reuse two bounded
workers if available. No worker runs builds, tests, simulator, Git mutations,
or further agents. One host build lease; SwiftPM uses two jobs.

Preserve unrelated AGENTS.md/CLAUDE.md edits and the two historical untracked
arbiter JSON files. Todo109 keyboard duplication is outside this scope.

## Proven red evidence

Source head `6d7ae8f`: [CI37097813025](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/37097813025)
failed its `ios` Build step on macos-14-arm64 image20260831.0302.1. Existing
SwiftPM tests were skipped because compilation failed. Local Xcode26.2 build,
679 tests, and native iOS acceptance previously passed; the older CI SwiftUI
SDK infers isolation differently. Root has saved the compiler log at
`/private/tmp/jasonette-ci-2026-10-03-ios-failure.log`.

Confirmed errors:

- HTMLComponent.swift233: synchronous nonisolated helper calls the explicitly
  MainActor-isolated HTMLContentWebView initializer.
- HTMLComponent.swift235/248: nonisolated helper mutates its isolated interaction
  property. Height sanitation also has an isolation warning at the callback.
- LayoutView.swift324: nonisolated horizontalComponents helper calls the isolated
  ComponentView initializer. The view's body already runs on the UI actor.

Head `5ade934`: [CI37097836328](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/37097836328)
failed only Markdown lint; source jobs skipped by path filters. Exactly one
MD012 failure: two blank lines at line84 of
`docs/plans/2026-10-02-ios-remaining-backlog-workflows.md`.
Xcode Cloud archive and Pages deployment succeeded for5ade934.

## Planning and implementation gate

Worker first reads this plan, the compiler log, HTMLComponent.swift,
LayoutView.swift, ComponentRegistry.swift and relevant existing tests. Report a
minimal isolation plan before edits. Initially approved product scope is only
HTMLComponent.swift and LayoutView.swift. Request any expansion explicitly.
Record diagnosis and exact annotations in this plan after root release.

Make UI isolation explicit where required by the existing UI lifecycle. Keep
pure numerical helpers usable as appropriate; asynchronous JavaScript callbacks
must update state on MainActor. Preserve iOS/macOS platform guards and older
supported Swift toolchain behavior. Do not suppress compiler checks, alter
package platforms, disable tests, or upgrade the runner to hide these errors.
Existing meaningful HTML/layout regressions remain the behavioral contract;
do not add source-string or annotation-mirroring tests.

### Approved compiler repair

Source inspection confirms that the older SDK isolates native representable
lifecycle requirements and `View.body`, but does not infer the same isolation
for their unannotated helper methods. Root approved the following annotations
before implementation:

- `@MainActor` on `HTMLWebView`, covering its native lifecycle and web-view
  creation/update helpers.
- `@MainActor` on `HTMLWebView.Coordinator`, covering binding, source and sizing
  mutations plus navigation delegate callbacks.
- `@MainActor` on `LayoutView`, covering both horizontal view-building helpers.
  The separate numerical sizing types remain unchanged.
- `nonisolated` on `HTMLComponent.defaultHeight`, `minimumHeight` and
  `sanitizedHeight(_:)`: immutable `CGFloat` values and pure height sanitation
  can be used directly in the JavaScript completion. The existing
  `Task { @MainActor in ... }` still applies the resulting measurement to state.

This repair preserves platform guards, loaded-source and sizing checks,
authored bounds and hit routing. Existing HTML interaction/background tests and
layout sizing tests provide behavioral coverage. Independent review and the
exact repair-head CI compiler gate must confirm older SDK protocol conformance.

Root removes the single extra documentation blank line and runs the existing
Markdown lint gate. Root may add xcodebuild/swift version reporting to the iOS
CI job to make compiler/SDK provenance visible, preserving runner and triggers.

## Review and completion gates

1. Independent xhigh source review: actor/protocol conformance under older and
   current SDKs, native lifecycle methods, coordinator/callback isolation,
   non-UI numerical helpers, and unchanged sizing/activation semantics.
2. Root local `swift build --jobs 2` and focused HTML/layout tests, followed by
   full `swift test --jobs 2 --quiet` only once integration is stable.
3. Root `npm run lint:md`; repair only concrete findings introduced here.
4. Commit and push scoped changes to main using the required keychain Git auth.
5. Observe the exact repair-head GitHub Actions run. The ios Build AND Test
   steps and Markdown lint must succeed; an overall-success documentation-only
   run with ios skipped does not satisfy this gate.
6. Check Xcode Cloud archive when reported for the repair head. Native behavior
   already has106–108 acceptance; repeat simulator work only if this repair
   changes behavior or a reviewer identifies a concrete UI risk.
7. Record run URLs, source hashes, local results, findings/resolutions and any
   actual limitation. Close110 and update handoff only after gates pass. Final
   metadata-only commit must also pass its triggered lint check.
