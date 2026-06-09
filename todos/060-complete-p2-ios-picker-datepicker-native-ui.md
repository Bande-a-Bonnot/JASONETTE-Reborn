---
id: "019ead73-fc5d-7d9b-b990-5e32a19222b4"
status: complete
priority: p2
issue_id: "060"
tags: [ios, actions, picker, datepicker]
dependencies: []
---

# Implement native iOS `$util.picker` and `$util.datepicker`

## Problem Statement

After the native vision work, `$util.picker` and `$util.datepicker` were the
remaining Jasonpedia Action-screen utilities shown only as recognized fallback
alerts. The canonical demos are embedded in `Jasonpedia/action/index.json`:

- `$util.picker` provides `options.items[]` with display `text` and optional
  item-level `action`.
- `$util.datepicker` expects a success payload containing `$jason.value` as a
  Unix timestamp in seconds.

## Fix

- Added injectable dispatcher seams for utility picker and date picker native UI.
- `$util.picker` now builds picker items from authored strings/dictionaries,
  presents native iOS selectable sheet UI, stores selection payload under local
  state and `$jason`, and executes selected item-level actions when present.
- Picker selection payload includes `index`, `text`, and `value`; absent authored
  `value` falls back to the selected index.
- `$util.datepicker` now presents native iOS date/time selection UI, stores Unix
  timestamp seconds under `$jason.value`, and passes that payload into success
  chains.
- Interactive sheet dismissal and explicit Cancel paths resume continuations via
  cancellable action errors instead of hanging.
- Added a narrow template compatibility path for the Jasonpedia datepicker
  success expression `(new Date(parseInt($jason.value) * 1000)).toString()`,
  including malformed timestamp coverage.

## Acceptance Criteria

- [x] `$util.picker` presents native UI when a handler is installed.
- [x] Selecting an item can execute the selected item action.
- [x] Picker selection payload flows into success chains when no item action is
      provided.
- [x] `$util.datepicker` returns `$jason.value` as Unix timestamp seconds.
- [x] Jasonpedia datepicker legacy date string expression renders for valid
      values and returns nil for malformed timestamps.
- [x] Sheet cancellation/dismissal does not leave action continuations hanging.

## Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testUtilityPicker` — 2 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testDatePicker` — 1 test, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ExpressionEvaluatorTests/testLegacyDateToString` — 2 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 563 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `cd JASONETTE-iOS/JasonetteApp && xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build` — passed (`** BUILD SUCCEEDED **`).
- `npm run lint:md` — 0 errors.

## Notes

Visual simulator QA for the embedded action-screen rows remains a useful follow
up, but the native UI seams and payload/action semantics are covered by targeted
unit tests and the iOS app target builds successfully.
