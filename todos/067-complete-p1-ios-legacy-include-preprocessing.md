---
id: "019f2ece-a72e-7e77-9239-5aa42848bbe5"
status: complete
priority: p1
issue_id: "067"
tags: [ios, parity, includes, templates, jasonpedia]
dependencies: []
---

# iOS legacy include preprocessing

## Problem Statement

The current iOS renderer has strong action/component coverage, but the parity
audit found that legacy Jasonette document preprocessing is still incomplete.
The original iOS/Android runtimes resolved `+`, `@`, and `$require` references
before rendering, while current iOS only has narrow `head.data["@"]` support.

This blocks parity for webcontainer, feed, shared template/style, and other
Jasonpedia fixtures that rely on remote or local includes.

See `docs/research/2026-07-04-cross-platform-parity-audit.md`.

## Acceptance Criteria

- Current iOS can resolve top-level and nested legacy `+` include references
  before template rendering.
- Current iOS can resolve legacy local `$document...` include references where
  the referenced content exists in the loaded document.
- Existing `head.data["@"]` remote mixin behavior remains intact.
- Include resolution is bounded and fails safely for cycles, excessive depth, and
  unsupported schemes.
- Add targeted unit tests plus at least one Jasonpedia fixture regression test
  for a webcontainer/feed include document.

## Suggested Files

- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/DocumentLoader.swift`
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Core/JasonDocument.swift`
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteViewModel.swift`
- `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Template/TemplateEngine.swift`
- `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/DocumentLoaderTests.swift`
- `JASONETTE-iOS/JasonetteApp/Tests/JasonetteTests/ViewModelTests.swift`

## Completion Notes

Implemented metadata-aware legacy include preprocessing for iOS URL loads and
bootstrap loads. The resolver expands top-level and nested `+` includes, selected
remote paths such as `items@...`, legacy local `$document...` references, and
legacy `@` data mixins while preserving fail-soft behavior for unavailable
`@` mixins. Include URL resolution follows the including document URL, rejects
unsupported schemes through the existing document URL allowlist, detects cycles,
and caps recursion depth. Jasonpedia webcontainer iframe/feed fixtures now
resolve before template rendering, including fetch-once template includes inside
`#each` loops.

Also scoped a template-engine compatibility fix for nested split conditional
arrays so Jasonpedia feed item component arrays decode without flattening
ordinary arrays-of-arrays.

## Verification

```bash
cd JASONETTE-iOS/JasonetteApp
swift test --filter DocumentLoaderTests/testLoadResolvingIncludesWithMetadataDoesNotTreatAtInsideURLAsPathSeparator
swift test --filter DocumentLoaderTests
swift test --filter TemplateEngineTests
swift test --filter ViewModelTests/testJasonpediaWebContainerFeedResolvesIncludesThroughViewModelLoad
swift test
swift build
```
