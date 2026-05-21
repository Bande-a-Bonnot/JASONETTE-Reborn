---
status: complete
priority: p1
issue_id: "039"
tags: [ios, templates, compatibility, jasonpedia, qa]
dependencies: []
---

# Support object-form template directives under array fields

Completed: 2026-05-20

## Resolution

Implemented in `ee81808 Fix object-form each item context` and verified by `183e724 Document post-fix simulator QA`.

- `TemplateEngine` expands object-form `items` directives into arrays.
- `#each` item dictionaries expose fields as direct identifiers (`{{title}}`, `{{url}}`, etc.) while preserving `{{$jason}}`, `this`, `$index`, and `$root`.
- Added TemplateEngine regression coverage for object-form `items`, nested components, and non-array empty output.
- Added ViewModel fixture tests for `Jasonpedia/template/index.json` and `Jasonpedia/action/network/index.json`.
- Simulator screenshots in `docs/qa/2026-05-20-ios-simulator-post-fix-qa.md` confirmed the Template and `$network` blank-list regressions are gone.

## Problem Statement

The iOS renderer does not correctly render original Jasonette template syntax
where an array-valued field is authored as an object containing a directive key,
for example:

```json
"items": {
  "{{#each json_items}}": {
    "type": "vertical",
    "href": { "url": "{{url}}" },
    "components": [ ... ]
  }
}
```

During the 2026-05-18/19 simulator QA pass, pages using this syntax rendered
section headers but blank/empty tappable content areas. This blocks major
Jasonpedia demos.

## Evidence

- QA doc: `docs/qa/2026-05-18-ios-simulator-complete-qa.md`
- Screenshots:
  - `docs/qa/artifacts/2026-05-18-ios-simulator/010-template-blank-buttons.png`
  - `docs/qa/artifacts/2026-05-18-ios-simulator/007-network-empty-tabs.png`
- Affected fixtures observed:
  - `Jasonpedia/template/index.json`
  - `Jasonpedia/action/network/index.json`

## Recommended Action

1. Extend the template/render pipeline so object-form directive expansion can
   produce arrays for array-valued fields such as `sections[].items`.
2. Preserve current supported array-form `{{#each}}` behavior.
3. Add regression fixtures/tests for:
   - object-form `items` with `{{#each ...}}`
   - nested component arrays inside each produced item
   - missing/non-array data yielding an empty array rather than blank phantom
     controls
4. Re-run the simulator smoke path for Template and Action → `$network`.

## Acceptance Criteria

- [x] `Jasonpedia/template/index.json` shows visible/tappable entries such as
      Inline Data, Dynamic Data, #each, and conditionals
- [x] `Jasonpedia/action/network/index.json` shows visible/tappable entries such
      as imagejason, eliza, and Microblog with user account
- [x] Unit tests cover object-form directive expansion under `items`
- [x] Existing template tests still pass
- [x] Simulator QA screenshots confirm the blank-list regression is gone

## Notes

This is likely a compatibility gap between original Jasonette template syntax
and the current Swift `JasonSection.items` decoding/rendering path.
