---
status: ready
priority: p3
issue_id: "029"
tags: [ios, api-drift, nit]
dependencies: []
---

# Modernize `onChange(of:perform:)` once iOS 17 is the floor

## Problem Statement

gemini-code-assist flagged the shell's
`onChange(of: shell.selectedTabID) { newID in … }` call site as using
the `onChange(of:perform:)` signature deprecated in iOS 17. The modern
forms are `onChange(of:_:)` (single-param, old→new closure) and
`onChange(of:initial:_:)` (fires once on mount too).

## Findings

- `Package.swift` declares `.iOS(.v16)` as the minimum deployment
  target. The modern `onChange` overloads require iOS 17+.
- The deprecated signature still compiles (warning, not error) on
  iOS 17+ and is the only form that works on iOS 16.
- We're not willing to drop iOS 16 just to silence this specific
  deprecation.

## Recommended Action

When the project floor moves to iOS 17 (or higher), rewrite the
call site as:

```swift
.onChange(of: shell.selectedTabID) { _, newID in
    storedKey = shell.selectedCanonicalKey
    mounted.insert(newID)
}
```

and remove any lingering single-param closures elsewhere
(`grep -rn 'onChange(of:' Sources/`).

## Acceptance Criteria

- [ ] `Package.swift` minimum iOS target is `.v17` or higher
- [ ] No `onChange(of:perform:)` call sites remain
- [ ] Xcode build emits no "deprecated in iOS 17" warnings for
      `onChange`

## Notes

Source: gemini round-4 review on PR #20
([comment 3106831640](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/pull/20#discussion_r3106831640)).
