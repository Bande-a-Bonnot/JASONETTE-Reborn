---
status: complete
priority: p3
issue_id: "043"
tags: [ios, qa, simulator, developer-experience]
dependencies: []
---

# Add debug launch URL override for simulator QA

## Problem Statement

The iOS app currently hardcodes its entry URL in `Sources/JasonetteApp-iOS/App.swift`.
During simulator QA, this made it difficult to launch directly into specific
Jasonpedia fixtures or ad-hoc local QA documents such as action-only tab cases.

## Evidence

- QA doc: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- QA doc: `docs/qa/2026-05-23-ios-html-component-qa.md`
- Action-only footer tab behavior could not be manually validated end-to-end
  because no Jasonpedia fixture was found and changing the launch document would
  require code edits/rebuilds.
- HTML component visual QA again required temporarily editing `App.swift`,
  rebuilding, installing, and restoring the source file afterward.

## Recommended Action

1. Add a debug-only launch argument or environment variable for the entry URL,
   e.g. `JASONETTE_ENTRY_URL` or `-JasonetteEntryURL`.
2. Keep production/TestFlight behavior unchanged.
3. Document usage with `agent-device`/Simulator in QA docs.
4. Add a small local fixture strategy for testing tabs/action tabs without
   modifying app source.

## Acceptance Criteria

- [x] Debug simulator runs can override the root Jasonette URL without source
      edits
- [x] Release/TestFlight builds still use the production demo URL
- [x] QA docs show the exact command to launch with an override
- [x] Action-only tab and tabs fixtures can be tested directly in simulator QA

## Notes

This is a developer-experience enabler for repeatable exploratory and regression
QA, not a user-facing feature.

## Completion Notes

Completed on 2026-05-25.

- Added `JasonetteLaunchConfiguration` with debug-only entry URL overrides via
  `-JasonetteEntryURL`, `-JasonetteEntryURL=...`, and `JASONETTE_ENTRY_URL`.
- Kept release behavior locked to the production Jasonpedia demo URL by default.
- Updated the iOS app entrypoint to use the shared launch configuration.
- Added `LaunchConfigurationTests` covering environment override, launch
  argument precedence, equals-form parsing, release-mode ignoring, and non-HTTP
  scheme rejection.
- Added local simulator QA fixtures under
  `docs/qa/fixtures/ios-simulator-tabs/` for document tabs, action `$href` tab
  switching, and action forwarding.
- Documented exact `simctl` and `agent-device` usage in `docs/qa/README.md`.

Verification:

- `jq empty docs/qa/fixtures/ios-simulator-tabs/*.json`
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter LaunchConfigurationTests`
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 488 tests, 0 failures
- `cd JASONETTE-iOS/JasonetteApp && swift build`
