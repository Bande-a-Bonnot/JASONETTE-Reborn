---
status: ready
priority: p3
issue_id: "035"
tags: [ios, tabs, urls, security, code-review]
dependencies: []
---

# Define shell footer-tab icon URL scheme policy

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

- [ ] Footer-tab icon scheme behavior is documented in code/tests
- [ ] Disallowed icon schemes are either rejected or explicitly preserved by policy
- [ ] Tests cover at least `https`, `file`, and one custom scheme
- [ ] Non-tab image scheme behavior is audited or linked to a follow-up

## Notes

Deferred from PR #24 because the inconsistency predates relative URL resolution,
and tightening image scheme policy may affect currently-authored content. PR #24
is scoped to resolving shell-mounted tab descriptor URLs against the document
base.
