# iOS Luna QA pass — 2026-09-24

## Goal

Run an independent, evidence-backed QA pass on the **Swift iOS renderer** at
the current checkout. Discover actionable regressions or gaps without assuming
that defects must exist. Report what was actually exercised, separate product
defects from simulator/tooling failures, and give the owner a short prioritized
follow-up list.

## Scope and source of truth

- Read `AGENTS.md`, `docs/HANDOFF.md`, and `docs/qa/README.md` first.
- Read the iOS audit at
  `docs/plans/2026-03-28-fix-ios-components-actions-audit-plan.md` and recent
  iOS QA reports so this pass probes under-tested paths instead of repeating
  already settled findings.
- Target the existing **iPhone 17 Pro, iOS 26.2** simulator with UDID
  `61EA0147-56E4-4399-8D51-F98A93B708A6`. Check it is still booted before
  using it. The app bundle ID is `com.bande-a-bonnot.jasonette`.
- The debug entry URL override and local fixture strategy are documented in
  `docs/qa/README.md`. Use fixture URLs or local fixtures where possible, so
  behavior can be reproduced. Keep this pass on iOS; the recent Web HTML work
  is separate.
- Focus on representative rendering, navigation, state/action chains, input,
  and one native capability where feasible. Prefer paths with limited recent
  simulator evidence. Do not make a broad claim from a single screen.

## Method and evidence

1. Record the checkout commit, simulator/runtime, app build, and exact test or
   launch commands. Run `swift test` in `JASONETTE-iOS/JasonetteApp`, then build
   and launch the Debug iOS app following `docs/qa/README.md` if the toolchain
   allows it.
2. Use `agent-device` for interaction if it works. The known startup issue is
   tracked in `todos/065-p3-stabilize-agent-device-ios-snapshot-qa.md`. Make one
   bounded attempt, then use `simctl` launch/openurl/screenshot, XCTest, and
   logs as appropriate. A tooling failure is a QA coverage limit, not an app
   defect.
3. For each suspected product issue, reproduce it twice or pair a simulator
   observation with a focused code/test check. Save a screenshot or concise log
   excerpt when it materially supports the claim. Include expected and actual
   behavior, fixture/steps, severity, and likely owner file. Do not create a
   work item for an unverified hunch.
4. Write one report under `docs/qa/` dated 2026-09-24. Save artifacts under a
   matching directory in `docs/qa/artifacts/`. Suggest or draft `todos/`
   work items for verified issues, using UUIDv7 IDs and the repository todo
   format. Avoid duplicate todos by searching existing files first.

## Boundaries

- QA only: do not edit product Swift code, project configuration, or existing
  tests during this pass. The primary agent will review and decide fixes.
- Preserve the user’s existing edits to `AGENTS.md` and `CLAUDE.md` and the
  untracked historical arbiter JSON files. Do not stage or commit them.
- Do not use authenticated Git operations or publish results. The primary
  agent will review and commit the report and any verified work items.
- If interactive automation remains blocked, complete the strongest available
  non-interactive QA and state precisely which interactions could not be checked.

## Done

A reproducible report states pass/fail/inconclusive by path, includes the
environment and commands, and lists verified follow-ups in priority order.
There is no quota of findings.
