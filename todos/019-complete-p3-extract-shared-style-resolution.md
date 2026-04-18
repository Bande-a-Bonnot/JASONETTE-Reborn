---
status: complete
priority: p3
issue_id: "019"
tags: [refactor, code-quality, code-review, dry]
dependencies: []
---

# Extract shared style resolution helper — ADDRESSED IN PR #17

## Resolution
Centralized in PR #17. Added `JasonStyle.resolve(className:inline:headStyles:)` (single source of truth) and `JasonStyle.resolve(for:headStyles:)` (component convenience). All four call sites delegate: `JasonStyleModifier.resolved`, `JasonetteView.resolveLayerStyle`, `FooterTabItemView.resolvedStyle`, and the `StyleModifierTests.resolveStyles` test helper.

## Problem Statement (original)
`resolveLayerStyle` in `JasonetteView.swift` duplicates the class+inline merge logic from `JasonStyleModifier.resolved`. Three reviewers flagged this independently (Gemini, Copilot, CodeRabbit).

## Findings
- Location: `JasonetteView.swift:155-167` (resolveLayerStyle)
- Mirror of: `JasonStyleModifier.swift:19-31` (resolved computed property)
- Both split space-separated class names, merge head styles in order, then overlay inline style
- Risk: drift if one is updated without the other

## Recommended Action
Extract a shared free function:
```
func resolveStyle(className: String?, inlineStyle: JasonStyle?, headStyles: [String: JasonStyle]) -> JasonStyle
```
Call from both `JasonStyleModifier.resolved` and `layerView`. Add one test for the shared helper.

## Acceptance Criteria
- [ ] Single implementation of class+inline style merging
- [ ] Both callsites use the shared helper
- [ ] Test covers multi-class + inline override precedence

## Notes
Source: Gemini, Copilot, CodeRabbit on PR #13 (2026-03-29/30)
