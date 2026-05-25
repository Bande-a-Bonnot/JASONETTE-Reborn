---
status: complete
priority: p3
issue_id: "027"
tags: [ios, tabs, dedupe, code-review]
dependencies: ["026"]
---

# Content-based canonical key for action-only tabs

## Problem Statement

`TabDescriptor.Target.canonicalKey` is used to dedupe tabs during
bootstrap and to persist the selected tab across launches via
`@SceneStorage`. For `.document(URL)` / `.web(URL)` / `.app(URL)` the
key is the absolute URL string — stable and identity-free. For
`.action(JasonAction)` the key is an `ObjectIdentifier`, which is the
Swift reference address of the `JasonAction` instance. Two separately
decoded copies of an identical action block would get different keys,
so:

- A JSON re-decode (e.g. after `$reload` in tabbed mode, if/when
  action tabs survive bootstrap — see todos/026) would fail to match
  the previously-selected tab by canonical key.
- Duplicate action tabs cannot be deduped the way duplicate URL tabs
  are.

CodeRabbit flagged this during PR #20 review.

## Findings

- Source:
  `JASONETTE-iOS/.../Navigation/TabDescriptor.swift`
  `Target.canonicalKey` switch — `.action` branch uses
  `ObjectIdentifier(action).debugDescription`
- Pre-requisite: todos/026 (action-tab dispatch) must land first —
  otherwise action tabs can't reach the shell in the first place
- `JasonAction` shape:
  - `type` (String, e.g. `"$reload"`)
  - `options` (AnyCodable dictionary)
  - `success` / `error` nested actions
  - `action` inline-chain reference
- Stable hashing requires a canonical traversal of that graph; using
  the JSON encoding of the action block would work, subject to key
  ordering and float representation stability

## Recommended Action

Add a derived `stableHash: String` to `JasonAction` (or a free helper)
that:

- Encodes the action to JSON with `JSONEncoder.OutputFormatting
  .sortedKeys`
- Hashes the resulting `Data` with SHA-256 (CryptoKit)
- Returns the hex digest

Use that digest in `Target.canonicalKey` for the `.action` case:

```swift
case .action(let action):
    return "action:\(action.stableHash)"
```

Tests:

- Two independently-decoded copies of the same action JSON produce
  equal canonical keys
- Different action types / option values produce different keys
- Nested `success` / `error` branches participate in the hash

## Acceptance Criteria

- [x] `.action` canonical keys are content-derived, not identity-based
- [x] Identical action JSON ⇒ identical key across decode cycles
- [x] Dedupe during bootstrap drops duplicate action items (parity
      with URL-tab dedupe)
- [x] `@SceneStorage` restore applicability documented: action-only tabs are
      intentionally non-selectable, so selected-tab restoration still only
      restores document tabs; action canonical keys are nevertheless stable if
      used for persistence/dedupe.

## Notes

Source: CodeRabbit nitpick on PR #20 (2026-04-19).
Low priority until action tabs actually reach the shell (gated by
todos/026).

## Completion Notes

Completed on 2026-05-25.

- Added `JasonAction.stableHash`, using sorted-key JSON encoding plus SHA-256
  via CryptoKit.
- Swapped `.action` tab canonical keys from `ObjectIdentifier(action)` to
  `action.stableHash`.
- Added TabNavigationCoordinator coverage for stable keys across independent
  decodes, changed content producing changed keys, nested `success` / `error`
  branch participation, and duplicate action-tab dedupe during bootstrap.
- Note: action-only tabs remain intentionally non-selectable, so
  `@SceneStorage` selected-tab restore continues to apply to document tabs, not
  action tabs.

Verification:

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter TabNavigationCoordinatorTests`
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 492 tests, 0 failures
- `cd JASONETTE-iOS/JasonetteApp && swift build`
