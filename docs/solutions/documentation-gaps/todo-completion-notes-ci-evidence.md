---
title: "Todo completion and handoff notes must not overclaim CI evidence"
date: 2026-04-26
category: documentation-gaps
module: Documentation / Development Workflow
problem_type: documentation_gap
component: documentation
severity: medium
applies_when:
  - "Closing a todo based on PR or CI evidence"
  - "Updating handoff docs with current test or CI status"
  - "Local verification was blocked and CI is the only execution evidence"
  - "Path-filtered workflows may run, skip, or no-op depending on event type"
tags: [handoff, todos, ci, evidence, documentation, pr-workflow, android]
---

# Todo Completion and Handoff Notes Must Not Overclaim CI Evidence

## Context

Codex 5.5 xhigh reviewed the Android CI fix session and found two documentation
precision issues. The code fix was acceptable, but the todo/handoff prose risked
claiming more than had actually been verified: "Android CI green on main" and
"non-Android-change PR acceptance" need evidence tied to specific PRs, events,
checks, and dates.

Handoff docs become the next agent's starting reality. Overstated status is a
real defect even when the code is correct.

## Guidance

### Use evidence grammar for CI claims

When updating a todo or handoff, write CI claims with four parts:

```markdown
Claim:
Evidence:
- PR/run/SHA:
- Event type:
- Job/check name:
- Date:
Scope:
- What this proves:
- What this does not prove:
Local constraints:
- What could not be run locally and why:
```

Prefer precise claims:

```markdown
The `pull_request` Android job ran and passed on PR #21 before merge, and ran
again on non-Android-change PR #22 before merge. Local Gradle verification was
blocked because this environment has no Java runtime.
```

Avoid broad claims unless they are directly verified:

```markdown
Android CI is green on main.
```

That statement needs a post-merge main run where the Android job actually ran;
path-filtered workflows may otherwise skip or no-op.

### Distinguish CI signal types

| Term | Meaning |
|------|---------|
| **Exercised green** | The job actually ran the relevant build/test command and passed. |
| **Skipped/no-op green** | The workflow/check passed because path filters or conditions skipped work. |
| **Required green** | Branch protection accepted the status as passing. |

A todo acceptance criterion should say which kind of green it requires. For the
Android Kotlin test compile fix, the meaningful evidence was:

- PR #21 exercised the `pull_request` Android job after the Android test fix.
- PR #22 exercised the `pull_request` Android job on a non-Android-change PR,
  because this workflow runs Android on every PR, showing unrelated PRs were no
  longer blocked by the pre-existing Kotlin compile failure.

### Mark local gaps explicitly

If local verification cannot run, say so next to the CI evidence:

```markdown
Local: attempted `./gradlew :app:compileDebugUnitTestKotlin`, blocked by no Java
runtime in this environment.
CI: Android check passed on PR #21 and PR #22 before merge.
```

Do not hide local gaps behind CI success; future agents need to know whether a
machine setup issue remains.

## Why This Matters

Completion notes are durable coordination artifacts. If they overclaim, future
agents may skip verification, trust stale CI status, or misdiagnose a path-filter
skip as a real build pass. This is especially risky in monorepos where pull
request workflows and `main` push workflows intentionally run different subsets
of jobs.

Reviewers can catch documentation truthfulness issues just like code bugs. In
this session, Codex 5.5 xhigh found P3 evidence overclaims after CodeRabbit and
Gemini had already reviewed the code path.

## When to Apply

- Before marking a todo `complete`.
- Before updating `docs/HANDOFF.md` test-suite or CI status.
- When a CI job is path-filtered or event-conditioned.
- When a local command is attempted but blocked by environment setup.
- When a PR is merged despite a bot being rate-limited or not submitting a
  formal review.

## Examples

### Good todo note

```markdown
Completed in PR #21, squash `92e65dd` (2026-04-26). Android CI passed on PR #21
before merge, and passed again on non-Android-change PR #22 before merge. Local
Gradle verification was blocked by this environment having no Java runtime.
```

### Good handoff note

```markdown
Android CI: `pull_request` Android job ran/passed on PR #21 and
non-Android-change PR #22 before merge (2026-04-26); Kotlin JSON primitive
accessor compile failures fixed by squash `92e65dd`.
```

### Bad handoff note

```markdown
Android CI is green on main.
```

Unless a post-merge `main` run where Android actually executed was checked, this
is too broad.

## Related

- [`deferred-feedback-todo-four-part-structure.md`](../best-practices/deferred-feedback-todo-four-part-structure.md) — structure for creating tracked follow-up todos.
- [`automated-review-comment-handling.md`](../best-practices/automated-review-comment-handling.md) — bot review triage and reply patterns.
- [`multi-model-review-coderabbit-plus-codex-xhigh.md`](../best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md) — Codex xhigh as a second-pass reviewer, including documentation overclaim checks.
