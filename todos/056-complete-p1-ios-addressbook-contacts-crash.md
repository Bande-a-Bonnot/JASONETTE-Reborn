---
id: "019e947d-d65e-77d1-a23f-d0295bde07aa"
status: complete
priority: p1
issue_id: "056"
tags: [ios, actions, contacts, addressbook, crash, qa]
dependencies: []
---

# Fix iOS `$util.addressbook` Contacts crash after permission

## Problem Statement

The delegated iOS action-screen QA pass on 2026-06-03 found that the direct
Jasonpedia addressbook fixture crashed after Contacts access was granted and
crashed immediately on relaunch when permission was already granted.

Crash root cause from `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/addressbook-crash.log`:

```text
CNPropertyNotFetchedException: A property was not requested when contact was fetched.
Contacts -[CNContact middleName]
Contacts +[CNContactFormatter stringFromContact:style:]
JasonetteView.contactDisplayName
```

## Fix

- Replaced `CNContactFormatter.string(from:style:)` with an explicit display-name
  builder that only reads fetched keys: `givenName`, `familyName`, and
  `organizationName`.
- Extracted address-book payload construction to
  `AddressBookContactPayloadBuilder` so the fetch keys and payload formatting stay
  together.
- Preserved the legacy Jasonpedia payload shape:
  `name`, `phone: [{type,text}]`, and `email`.
- Kept Contacts permission/native failures routed through the existing action
  error path.

## Acceptance Criteria

- [x] The crash root cause is removed: fetched-contact name formatting no longer
      reads unrequested formatter-only properties such as `middleName`.
- [x] Relaunch with already-granted permission uses the same safe payload builder.
- [x] Contact payloads still include `name`, `phone`, and `email` in the legacy
      shape expected by Jasonpedia templates.
- [x] Added regression coverage for fetched-contact name formatting without
      unrequested properties.
- [x] Ran targeted addressbook tests and full `swift test`.

## Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter AddressBookContactPayloadTests` — 2 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testAddressBook` — 3 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 549 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `cd JASONETTE-iOS/JasonetteApp && mise exec -- tuist generate --no-open` — passed.
- Generic iOS Simulator `xcodebuild` Debug build — passed.

## Notes

A live direct-entry Simulator relaunch smoke test was attempted on 2026-06-05,
but local CoreSimulator became unreliable: the iPhone 17 Pro simulator hung at
`Waiting on System App`, the already-booted SE path timed out during simctl
install/launch, and a stale zero-byte `.git/index.lock` plus generated
`DerivedDataQA` had to be cleaned. The code path that crashed is covered by the
new Contacts payload regression and the generic Simulator build.
