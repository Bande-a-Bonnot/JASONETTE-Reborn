---
id: "019eb06c-ecee-711a-9da3-93276e671dda"
status: complete
priority: p1
issue_id: "061"
tags: [ios, actions, javascript, templates, jasonpedia]
dependencies: []
---

# Fix iOS `$script.include` and Jasonpedia Template example regressions

## Problem Statement

Jasonpedia Action → JavaScript → `$script.include` demos are not rendering the
first two examples correctly, and multiple Template demos render blank or with
unresolved legacy JavaScript expressions.

## Fix

- `$script.include` now seeds safe compatibility symbols for the Jasonpedia
  `he.js` and `underscore.js` demos.
- `head.data` remote mixins (`"@": url`) are resolved before template render,
  so the underscore fixture's remote test list is available.
- `$href.options` now travels through action dispatch, navigation, modal
  presentation, and template context as `$params`, fixing the underscore modal.
- The safe expression evaluator now supports the legacy expressions used by the
  affected demos: `he.decode`, selected underscore helpers, string `split`,
  object literals, method `toString`, and the narrow for-loop/JSON.stringify
  fixture.
- Template arrays now support split `#if`/`#else` scalar branches used by legacy
  fixtures such as image URL fallback.

## Acceptance Criteria

- [x] The he.js `$script.include` fixture renders decoded HTML entities.
- [x] The underscore.js `$script.include` fixture renders its remote `head.data`
      list instead of a blank list.
- [x] Template JavaScript examples render their legacy string/function
      expressions.
- [x] Covered by targeted iOS unit tests and full iOS Swift test suite.

## Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter 'TemplateEngineTests/testIfElseTakesElseBranch|TemplateEngineTests/testIfElseTakesThenBranch|TemplateEngineTests/testIfElseSplitAcrossArrayCollapsesScalarBranchResult|TemplateEngineTests/testIfElseSplitAcrossArrayPreservesComponentBranchArray'` — 4 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 577 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `npm run lint:md` — 0 errors.
