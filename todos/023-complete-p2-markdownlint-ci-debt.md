---
status: complete
priority: p2
issue_id: "023"
tags: [ci, markdownlint, docs, hygiene]
dependencies: []
---

# Fix pre-existing markdownlint CI debt (blocks green CI)

## Problem Statement

The `lint` job in CI has been red on `main` for every PR since the 015–022 todo files landed. 66 markdownlint errors, all MD022 (blanks-around-headings), across 12 files. Every subsequent PR inherits the red check even when the PR itself introduces no lint violations.

## Findings

- Failing files: `todos/015-ready-p3-sectionview-code-duplication.md` through `todos/022-ready-p3-footer-button-image-failure-placeholder.md` (8 files), plus 4 others surfaced by the full run
- Exclusive violation: MD022 — every `##`/`###` heading needs a blank line above and below
- Root cause: todo template lacks the blank lines around `## Problem Statement`, `## Findings`, etc. Each new todo inherits the pattern
- Confirmed on PR #17 (commit `604eaa7`): all 66 failures exist in files this PR never touched
- Run: `gh api repos/Bande-a-Bonnot/JASONETTE-Reborn/actions/jobs/71930299782/logs`

## Recommended Action

1. Run `markdownlint-cli2 --fix 'todos/**/*.md'` locally to auto-fix MD022
2. Fix the todo template (if there is one) so new todos start compliant
3. Consider adding a pre-commit hook or `.markdownlintignore` entry — blank lines around headings is a stable convention and the auto-fix is safe

## Acceptance Criteria

- [x] `lint` job passes on `main` (green check on next push)
- [x] Running `markdownlint-cli2` on todos/ returns zero errors
- [x] New todo files added after this fix pass lint without manual cleanup

## Notes

Deferred out of PR #17 scope — the PR is about network response handling and footer tab items, not markdown hygiene. Opening as P2 because it blocks the CI green signal every reviewer expects.

Source: PR #17 review loop, 2026-04-18.

## Completion Notes

Completed: 2026-06-11

Markdown lint debt is cleared; `npm run lint:md` now scans the repository markdown set with zero errors.

Verification: `npm run lint:md` — 0 errors.
