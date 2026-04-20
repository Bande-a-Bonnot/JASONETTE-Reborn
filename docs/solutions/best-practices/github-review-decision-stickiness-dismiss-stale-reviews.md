---
title: "GitHub reviewDecision is sticky: dismiss stale formal reviews to unblock merge"
date: 2026-04-19
category: best-practices
module: Development Workflow
problem_type: best_practice
component: development_workflow
severity: medium
applies_when:
  - "A PR shows mergeStateStatus=UNSTABLE with mergeable=MERGEABLE and reviewDecision=CHANGES_REQUESTED"
  - "A reviewer (human or bot like CodeRabbit) posted a formal CHANGES_REQUESTED review, then later commented approval prose without submitting a new formal review"
  - "Branch protection blocks merge on CHANGES_REQUESTED even though all raised concerns are addressed"
  - "CodeRabbit posts 'LGTM' / approval-shaped issue comments after an earlier formal CHANGES_REQUESTED review"
tags: [github, pr-workflow, code-review, coderabbit, branch-protection, gh-cli, review-dismissal]
---

# GitHub reviewDecision Is Sticky: Dismiss Stale Formal Reviews to Unblock Merge

## Context

PR #20 sat in UNSTABLE state with all CI green and every raised concern
addressed in follow-up commits. CodeRabbit had posted "LGTM" / approval prose
as an **issue comment** in subsequent passes. Merge was still blocked.

Root cause: GitHub's `reviewDecision` GraphQL field is driven only by **formal
pull request reviews** (`APPROVED` / `CHANGES_REQUESTED` / `COMMENTED` events
submitted via the Reviews API). Issue-comment prose — no matter how
approval-shaped — does not transition review state. An early
`CHANGES_REQUESTED` formal review stays in effect until the same reviewer
submits a **new** formal review, or until the stale one is dismissed.

On unprotected branches this surfaces as `mergeStateStatus: UNSTABLE`. On
protected branches with "require review resolution" it hard-blocks merge.

## Guidance

**Diagnose first, then dismiss.** Do not re-request review or push empty
commits hoping to bump state — neither clears `reviewDecision`.

### Diagnostic sequence

```bash
# 1. Smell test — MERGEABLE + UNSTABLE + CHANGES_REQUESTED is the fingerprint
gh pr view <PR> --json mergeable,mergeStateStatus,reviewDecision

# 2. Find the stale formal review (look for state=CHANGES_REQUESTED)
gh api repos/{owner}/{repo}/pulls/<PR>/reviews \
  --jq '.[] | {id, user: .user.login, state, submitted_at}'

# 3. Dismiss it
gh api -X PUT repos/{owner}/{repo}/pulls/<PR>/reviews/<review_id>/dismissals \
  -f message="Concerns addressed in subsequent commits"
```

After the dismissal, the review's state becomes `DISMISSED` and
`reviewDecision` either clears or reflects the next formal review.
`mergeStateStatus` transitions to `CLEAN` (or `BLOCKED` if other required
checks are still pending, which is a different problem).

### What does NOT work

| Attempt | Why it fails |
|---------|--------------|
| Waiting for CodeRabbit's "LGTM" issue comment to flip state | Issue comments are not review submissions; the API never reads them for `reviewDecision` |
| Pushing a new commit | New commits do not invalidate prior reviews unless the repo has "dismiss stale reviews" enabled, and even then dismissal is the same endpoint under the hood |
| `@coderabbitai resolve` on a PR where the formal review is CHANGES_REQUESTED | Resolves the bot's thread markers but does not submit a new formal review |
| Re-requesting review from the bot | Queues a new review but the old one still counts until replaced or dismissed |

### One-liner for CodeRabbit specifically

```bash
PR=20 OWNER=bande-a-bonnot REPO=JASONETTE-Reborn
STALE=$(gh api repos/$OWNER/$REPO/pulls/$PR/reviews \
  --jq '.[] | select(.user.login=="coderabbitai[bot]" and .state=="CHANGES_REQUESTED") | .id' \
  | head -1)
gh api -X PUT repos/$OWNER/$REPO/pulls/$PR/reviews/$STALE/dismissals \
  -f message="Concerns addressed in subsequent commits"
```

## Why This Matters

- Unblocks merge without re-requesting review or fabricating empty commits
- Documents the dismissal reason in PR history (auditable trail)
- Keeps reviewers honest — if the bot/human really does have unresolved
  concerns, they can submit a fresh formal review after dismissal
- Avoids the anti-pattern of "approving your own PR to work around a stale
  bot review", which bypasses actual review intent

## When to Apply

- `gh pr view` reports `mergeStateStatus: UNSTABLE` with all checks green
- `reviewDecision` is `CHANGES_REQUESTED` but the latest human/bot signal is
  an approval-shaped issue comment, not a formal review
- You have genuinely addressed the raised concerns (do not use this to
  bypass legitimate unresolved review feedback)

Skip when: the stale review is from a human reviewer who is still engaged —
ask them to approve or re-review instead.

## Examples

### Concrete instance — PR #20

- CodeRabbit submitted formal review `4135799620` with state
  `CHANGES_REQUESTED` early in the review cycle
- All raised issues fixed in subsequent commits on the same branch
- CodeRabbit posted approval-shaped issue comments ("LGTM") on the later
  passes — these do NOT submit new formal reviews
- `gh pr view 20 --json mergeable,mergeStateStatus,reviewDecision` showed
  `MERGEABLE` / `UNSTABLE` / `CHANGES_REQUESTED`
- Dismissing `4135799620` via the dismissals endpoint cleared
  `reviewDecision` and merge unblocked

### Dismissing from a script

```bash
dismiss_stale_coderabbit() {
  local pr=$1 owner=$2 repo=$3
  gh api "repos/$owner/$repo/pulls/$pr/reviews" \
    --jq '.[] | select(.user.login=="coderabbitai[bot]" and .state=="CHANGES_REQUESTED") | .id' \
  | while read -r id; do
      gh api -X PUT "repos/$owner/$repo/pulls/$pr/reviews/$id/dismissals" \
        -f message="Concerns addressed in subsequent commits"
    done
}
```

## Related

- [automated-review-comment-handling.md](./automated-review-comment-handling.md)
  — triage framework and the CodeRabbit `@coderabbitai resolve` pattern for
  nitpicks. That doc notes `CHANGES_REQUESTED` persists after pushing fixes;
  **this doc is the actual fix when `resolve` is insufficient.**
- [multi-model-review-coderabbit-plus-codex-xhigh.md](./multi-model-review-coderabbit-plus-codex-xhigh.md)
  — running codex xhigh as a second pass before CodeRabbit's formal review
  lands, reducing the chance of a stale CHANGES_REQUESTED in the first place
- GitHub REST: [Dismiss a review for a pull request](https://docs.github.com/en/rest/pulls/reviews#dismiss-a-review-for-a-pull-request)
