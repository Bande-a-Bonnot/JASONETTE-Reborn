---
status: complete
priority: p3
issue_id: "035"
tags: [ios, tabs, urls, security, code-review]
dependencies: []
---

# Define shell footer-tab icon URL scheme policy

Completed: 2026-04-30

## Problem Statement

Codex 5.5 xhigh review of PR #24 noted that `TabDescriptor.init(from:baseURL:)`
applies scheme allowlists to tab target URLs (`document`, `web`, `app`) after
relative resolution, but does not apply a scheme policy to `item.image` icon URLs.
That means absolute `file:` / custom-scheme icon strings can still be stored in
`TabLabelSpec.iconURL`, while tab targets are rejected.

SwiftUI `AsyncImage` is unlikely to fetch unsupported schemes usefully, but the
policy is inconsistent and should be deliberate rather than incidental.

## Recommended Action

1. Decide whether footer-tab icon URLs should be restricted to `http` / `https`
   or share a broader asset allowlist.
2. Apply the policy in `TabDescriptor.init(from:baseURL:)` after
   `JasonURL.resolve`.
3. Add tests for allowed `https` icons and rejected `file:` / custom-scheme icons.
4. Audit non-tab image renderers (`ImageComponent`, `ButtonComponent`, legacy
   footer views) for the same policy.

## Acceptance Criteria

- [x] Footer-tab icon scheme behavior is documented in code/tests
- [x] Disallowed icon schemes are either rejected or explicitly preserved by policy
- [x] Tests cover at least `https`, `file`, and one custom scheme
- [x] Non-tab image scheme behavior is audited or linked to a follow-up

## Completion Notes

- Shell-mounted footer-tab icon URLs now use the document/web allowlist
  (`http`/`https`) after `JasonURL.resolve`.
- `file:` and a custom scheme are covered by
  `testDescriptorDropsDisallowedIconSchemes`.
- `https` icon coverage exists in `testDescriptorIconReadsImageFieldNotTargetURL`
  and relative/root-relative icon tests.
- Non-tab relative image URL parsing was covered by the broader URL plumbing
  audit completed in `todos/034-complete-p2-codebase-wide-relative-url-resolution.md`.
- Non-tab absolute image scheme policy is tracked separately in
  `todos/036-ready-p3-non-tab-image-url-scheme-policy.md`.

## Notes

Original Codex PR #24 finding: `TabDescriptor.init(from:baseURL:)` applied
scheme allowlists to tab targets but not to `item.image` icon URLs.
