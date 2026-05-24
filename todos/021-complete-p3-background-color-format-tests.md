---
status: complete
priority: p3
issue_id: "021"
tags: [testing, code-review]
dependencies: []
---

# Add rgba() and #RRGGBBAA background color test cases

## Problem Statement

The body background tests cover `#RRGGBB` and `rgb()` formats but not `rgba()` or 8-digit hex (`#RRGGBBAA`). While `Color(css:)` already handles these formats (tested in its own unit tests), adding flow-through tests prevents format-support regressions in the ViewModel pipeline.

## Findings

- Location: `ViewModelTests.swift:211-281`
- CodeRabbit nitpick on PR #14
- `Color(css:)` parser supports: `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)`, `rgba(r,g,b,a)`
- Only `#RRGGBB` and `rgb()` are flow-tested through the ViewModel

## Recommended Action

Add two tests mirroring the existing pattern:
- `testBodyBackgroundRGBAColorFlowsThrough` with `"rgba(10,20,30,0.5)"`
- `testBodyBackgroundHex8ColorFlowsThrough` with `"#112233cc"`

## Acceptance Criteria

- [x] rgba() background string flows through renderedRoot
- [x] 8-digit hex background string flows through renderedRoot
- [x] Tests pass (`cd JASONETTE-iOS/JasonetteApp && swift test`, 473 tests, 0 failures, 2026-05-24)

## Notes

Source: CodeRabbit nitpick on PR #14 (2026-03-30)
