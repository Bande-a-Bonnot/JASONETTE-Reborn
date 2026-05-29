---
id: "019e7612-d0c7-797c-a5d7-1cbd67cb53ad"
status: open
priority: p3
issue_id: "050"
tags: [ios, components, textarea, accessibility, ux, qa]
dependencies: []
---

# Improve empty textarea visual/accessibility affordance

## Problem Statement

During delegated iOS Simulator QA on 2026-05-29, `View` → `Component` →
`textarea` initially looked mostly blank: only the section label and `Done`
button were obvious. The empty `TextEditor` did not appear as a `text-view` in
the initial accessibility snapshot; after coordinate focus and typing, it did
accept input and exposed a `text-view`.

Follow-up in the same session added a minimum width to `TextAreaComponent`, but
the empty state still has weak visual affordance because there is no obvious
border/placeholder in the fixture.

## Evidence

- QA report: `docs/qa/2026-05-29-ios-delegated-codex-xhigh-qa.md`
- Before/finding screenshot: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textarea.png`
- Follow-up focused/typed screenshot: `docs/qa/artifacts/2026-05-29-delegated-agent/component-textarea-after-fix-typed.png`
- Fixture: `Jasonpedia/view/component/textarea/index.json`

## Recommended Action

1. Decide the intended default empty textarea affordance for Jasonette iOS:
   border, background contrast, placeholder text, minimum size, or a combination.
2. Add renderer coverage where practical for the default sizing/placeholder path.
3. Verify with direct entry URL:
   `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/component/textarea/index.json`.
4. Capture before/after simulator evidence.

## Acceptance Criteria

- [ ] Empty textareas are visibly tappable in the Jasonpedia textarea fixture
- [ ] Empty textareas expose a useful accessibility target before focus where SwiftUI permits
- [ ] Focus, typing, Done toolbar, and keyboard dismissal still work
- [ ] Existing textfield/secure textfield behavior is unchanged
