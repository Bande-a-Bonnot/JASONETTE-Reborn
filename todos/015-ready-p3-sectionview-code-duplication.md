---
status: ready
priority: p3
issue_id: "015"
tags: [code-quality, swiftui, refactor, code-review]
dependencies: []
---

# Code Duplication in sectionView Horizontal/Vertical Branches

## Problem Statement
The `sectionView` method in `JasonetteView.swift` duplicates the `ForEach` + `ComponentView` construction between the horizontal and vertical branches. The only differences are the container wrapper and padding.

## Findings
- Location: `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift:140-164`
- The `ComponentView(item, headStyles:, onHref:, onAction:)` call is identical in both branches
- Horizontal wraps in `ScrollView(.horizontal) > HStack(spacing: 0)`
- Vertical uses bare `ForEach` with `.padding(.horizontal)` and `.padding(.vertical, 2)`
- Adding a third section type (e.g., "grid") would require copy-pasting again

## Proposed Solutions

### Option 1: Extract ForEach body into a helper
- **Pros**: Reduces duplication, single place to update ComponentView args
- **Cons**: SwiftUI @ViewBuilder extraction can reduce readability
- **Effort**: Small
- **Risk**: Low

## Recommended Action
Extract when a third section type is needed. Current duplication is localized and tolerable.

## Technical Details
- **Affected Files**: `JasonetteView.swift`
- **Related Components**: `ComponentView`, `LayoutView`
- **Database Changes**: No

## Resources
- Original finding: Gemini code review on PR #12
- Related: `LayoutView.swift` already handles horizontal/vertical for component-level layouts

## Acceptance Criteria
- [ ] ComponentView construction appears only once in sectionView
- [ ] Horizontal and vertical sections still render correctly
- [ ] Tests pass

## Work Log

### 2026-03-21 - Approved for Work
**By:** Claude Triage System
**Actions:**
- Issue approved during triage session
- Status set to ready
- Low priority — refactor when third section type is added

**Learnings:**
- SwiftUI @ViewBuilder extraction can make view code harder to read
- Current duplication is only two branches, localized in one function

## Notes
Source: Triage session on 2026-03-21
