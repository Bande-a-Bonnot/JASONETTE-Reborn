---
title: Deferred-feedback todos need four parts to stay load-bearing
date: 2026-04-19
category: best-practices
module: development_workflow
problem_type: best_practice
component: development_workflow
severity: medium
applies_when:
  - "A reviewer raises a valid concern that is genuinely out-of-scope for the current PR"
  - "Replying 'will address in follow-up' or 'deferred to a todo'"
  - "Multiple review rounds where the same reviewer may re-raise the same issue"
tags:
  - code-review
  - todos
  - deferral
  - scope-management
  - sentinel-tests
related_components:
  - testing_framework
  - documentation
---

# Deferred-feedback todos need four parts to stay load-bearing

## Context

In review-heavy PRs (PR #20's tab-navigation shell cycled through eight Gemini
rounds), reviewers surface concerns that are *valid but out-of-scope* — URL
normalization semantics raised during a ZStack-nav-bar review, NavigationStack
title collisions raised during a tab-identity review, etc.

The common reflex is to reply "deferred to a todo" and create a stub file
with a one-line task. That reflex produces a todo that **rots**: the next
review round the same reviewer re-raises it, nobody on the PR thread
remembers why it was deferred, and when the todo is eventually picked up the
original scope rationale — and the sentinel tests that locked in the
deliberate-scope behaviour — are gone.

A durable deferred-feedback todo captures four things. Fewer than four and
the deferral is a brush-off that the reviewer (or the codebase) will catch
later.

## Guidance

Every "deferred to todos/NNN" answer MUST have all four of:

### 1. Context — what was raised and by whom

Name the reviewer, the PR, and the round. Quote or paraphrase the concern.
This is what a future reader (including the same reviewer three rounds
later) uses to reconstruct "oh, right, this is the thing you already
flagged".

```markdown
## Context

Gemini flagged (round 6 + round 7 of PR #20) that `TabDescriptor.Target.canonicalKey`
uses `url.standardized.absoluteString`, and that `URL.standardized` does NOT normalize:
- Host casing — `https://Example.com/` vs `https://example.com/`
- Trailing slashes — `/home` vs `/home/`
- ...
```

### 2. The ask — the concrete change, usually a code sketch

Not "look into URL normalization" but the actual target API. A code sketch
locks in the shape of the eventual fix so the reviewer can confirm "yes,
that's what I was asking for" at deferral time, not rediscover it later.

```swift
extension URL {
    /// Jasonette-normalized form: lowercased scheme/host, trailing slash removed,
    /// default port dropped, query parameters sorted.
    var jasonetteCanonical: URL { ... }
}
```

### 3. Why not now — the *affirmative* case for deferral

This is the part that separates durable deferrals from brush-offs. State
the positive reason the work doesn't belong in this PR. Legitimate reasons
include:

- **Scope**: "PR #20 is tab navigation shell, not URL identity semantics."
- **Risk**: "Normalizing URL identity changes cache keys, deep-link
  matching, and auth-redirect flows — each needs its own review."
- **Call-site catalog gap**: "We don't yet have a catalog of every URL
  comparison in the codebase."
- **Review-bandwidth**: "Addressing this here would add N reviewers who
  aren't already on the thread."

"We didn't have time" is NOT an affirmative case. If the only reason is
time pressure, the todo will lose its defence on the next review cycle.

### 4. Locked-in tests — the sentinel test(s)

Name the test(s) that currently pin the deliberate-scope behaviour, and
declare that the test failure is the *signal* when the deferred work lands.

```markdown
## Locked-in tests

The current deliberate limit is pinned by:
- `testTrailingSlashIsNotAbsorbedByStandardization`

When we ship the canonical utility, this test will need to be updated (the
new expectation is that `/home` and `/home/` collapse to the same key).
**The test failure is the signal — don't change the production code
without updating these.**
```

Without (4), the deferred work lands months later and silently invalidates
the test contract. With (4), the red test is a forcing function to
reconsult the todo.

## Why This Matters

Deferred feedback is a trust contract with the reviewer. The contract has
two failure modes:

- **Re-raise loop**: without Context + Why-not-now, the reviewer re-raises
  the same concern next round. Every round costs a review cycle — on an
  eight-round PR, this compounds.
- **Silent drift**: without The-ask + Locked-in-tests, the eventual fix
  lands without the original scope rationale. Call-site catalogs go stale,
  sentinel tests are deleted as "obviously redundant", and the
  deliberate-scope decision evaporates into nobody's memory.

With all four parts, the PR author can reply "deferred to `todos/032`" and
the reviewer can confirm the deferral is load-bearing, not a brush-off.
The todo becomes a durable artefact, not a stub.

This is also why the four parts belong in the **todo file**, not in the PR
reply comment. PR comments disappear when the PR merges; the todo file
stays in the repo where the eventual fix happens.

## When to Apply

- Any P3-severity reviewer concern that is correct but out-of-scope
- Any "will address in follow-up" reply to an automated reviewer (Gemini,
  CodeRabbit, Copilot)
- Any scope-defence where the deliberate-scope behaviour is pinned by
  existing tests that the eventual fix will need to update

Not needed for:
- P1/P2 concerns (those get fixed in the same PR, not deferred)
- Style nits with no test or API surface (a one-liner todo is fine)
- Items the reviewer explicitly accepts as "declined, not deferred"

## Examples

Two in-tree exemplars, both written during PR #20 review cycles:

- `todos/032-nice-to-have-p3-codebase-wide-url-normalization.md` — URL
  normalization deferred during tab-navigation shell review. All four
  parts: Gemini round 6+7 context, `URL.jasonetteCanonical` code sketch,
  scope+risk+call-site rationale, `testTrailingSlashIsNotAbsorbedByStandardization`
  as the sentinel.
- `todos/031-nice-to-have-p3-investigate-zstack-nav-title-collision.md` —
  ZStack NavigationStack title collision deferred across Gemini rounds
  5/6/7/8. Context names the rounds, the ask is a concrete ForEach
  reordering fix, Why-not-now is "no real-world symptom observed yet" with
  a P3→P2 bump trigger, and locked-in behaviour is documented via the
  proposed snapshot test.

### Anti-pattern

```markdown
# TODO: fix URL normalization
Gemini asked for this.
```

No reviewer name, no round, no ask beyond the topic, no scope rationale,
no sentinel test. This todo will rot within one review cycle.

## Related

- `docs/solutions/best-practices/automated-review-comment-handling.md` —
  covers the triage framework that decides *whether* an item gets
  deferred (P3 → todo). This doc covers *how* the todo must be structured
  once that decision is made.
- `docs/solutions/best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md`
  — context on why review-heavy PRs produce many deferral candidates.
