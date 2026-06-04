---
id: "019e947d-d65e-77d1-a23f-d0295bde07aa"
status: open
priority: p1
issue_id: "056"
tags: [ios, actions, contacts, addressbook, crash, qa]
dependencies: []
---

# Fix iOS `$util.addressbook` Contacts crash after permission

## Context

The delegated iOS action-screen QA pass on 2026-06-03 found that the direct
Jasonpedia addressbook fixture crashes after Contacts access is granted and also
crashes immediately on relaunch when permission is already granted.

Evidence:

- `docs/qa/2026-06-03-ios-action-screen-qa.md`
- `docs/qa/artifacts/2026-06-03-ios-action-screen-qa/addressbook-crash.log`

Crash root cause from the log:

```text
CNPropertyNotFetchedException: A property was not requested when contact was fetched.
Contacts -[CNContact middleName]
Contacts +[CNContactFormatter stringFromContact:style:]
JasonetteView.contactDisplayName
```

## Ask

Request all contact keys needed by the formatter or avoid `CNContactFormatter`
for partially fetched contacts. The action should render contacts, an empty list,
or a Jasonette-authored error branch; it must not crash.

## Acceptance Criteria

- [ ] The direct `Jasonpedia/action/addressbook.json` fixture does not crash when
      contacts permission is granted.
- [ ] Relaunching the fixture with permission already granted does not crash.
- [ ] Contact payloads still include `name`, `phone`, and `email` in the legacy
      shape expected by Jasonpedia templates.
- [ ] Add regression coverage for fetched-contact name formatting without
      unrequested properties.
- [ ] Run targeted addressbook tests and full `swift test`.
