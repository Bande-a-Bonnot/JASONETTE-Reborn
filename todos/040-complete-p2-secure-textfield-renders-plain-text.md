---
status: complete
priority: p2
issue_id: "040"
tags: [ios, components, textfield, privacy, qa]
dependencies: []
---

# Render secure textfields with secure-entry semantics

Completed: 2026-05-22

## Resolution

Code fix is on `main` in `570f84d Render secure textfields securely`:

- `JasonStyle.secure` decodes/merges.
- `type: "textfield"` with truthy `style.secure` and legacy `type: "secure"` route through SwiftUI `SecureField`.
- ComponentDispatch, StyleModifier, and ViewModel fixture tests cover secure and non-secure renderer paths.
- Simulator fixture-load screenshot was captured in `docs/qa/2026-05-20-ios-simulator-post-fix-qa.md`.
- User confirmed the secure textfield is now correct in TestFlight/simulator after the fix shipped.

## Problem Statement

The `secure` textfield demo accepts text but displays and exposes the entered
secret as normal plain text. During simulator QA, entering `secret123` into the
secure field produced an accessibility node `text-field "secret123" [editable]`
and the value was visible on screen.

## Evidence

- QA doc: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- Screenshot: `docs/qa/artifacts/2026-05-18-ios-simulator/011-secure-field-visible.png`
- Jasonpedia path tested: `View` → `Component` → `textfield`

## Recommended Action

1. Identify the Jasonette field that marks a textfield as secure/password in
   the fixture/spec.
2. Route secure textfields through SwiftUI `SecureField` or equivalent secure
   UIKit-backed entry.
3. Preserve existing binding semantics with `StateManager`.
4. Add tests that decode/render the secure flag and verify the renderer chooses
   the secure path.
5. Re-run simulator QA on the textfield component demo.

## Acceptance Criteria

- [x] Secure textfield input is visually masked
- [x] Secure textfield is not exposed as a normal text field containing the raw
      secret value in accessibility snapshots
- [x] Non-secure textfields still render and bind normally
- [x] Tests cover secure and non-secure textfield paths

## Notes

This was already listed as a Phase C gap in the handoff, but QA confirmed it is
user-visible and privacy-sensitive.
