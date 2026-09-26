---
id: "01a0dd6d-49aa-771c-b974-848e8a9a1297"
status: open
priority: p3
issue_id: "108"
tags: [ios, actions, media, ux, qa]
dependencies: []
---

# Avoid the generic failure alert after ordinary media-picker cancellation

## Observed behavior and proposed improvement

Canceling the native photo picker in the Action demo stops the share chain,
but then presents `Action failed — Media capture was cancelled.` Requiring
another dismissal makes a normal user cancellation look like an app failure.

This is a UX improvement proposal. The action documentation does not prescribe
cancellation UI, so the report does not claim a callback-contract violation.

## Reproduction and evidence

1. Open the normal iOS app → Tutorial → Action.
2. Open `$media.picker + $util.share (photo)`.
3. Tap the native Photos Cancel button without selecting an image.
4. Observe the generic Action failed alert and dismiss it with OK.

Proposed result: return quietly when no authored error continuation exists;
keep the success/share continuation stopped.

- [Native picker](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker.png)
- [Cancellation alert](../docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/action-photo-picker-cancel-error.png)
- [QA report](../docs/qa/2026-09-26-ios-luna-exploratory-qa.md)

## Source corroboration

The fixture supplies a success-to-share chain and no error continuation.
`ActionDispatcher` propagates `mediaCaptureCancelled`; its generic catch branch
shows an Action failed alert when no error actions are present.

## Definition of Done

- Ordinary picker cancellation does not show the generic failure alert when
  the document supplies no error continuation.
- An authored error continuation still receives the cancellation outcome.
- Cancellation never runs success/share or changes selected-media state.
- Real permission, availability, and capture failures retain useful feedback.
- Focused action-chain coverage and a simulator cancel flow verify the result.
