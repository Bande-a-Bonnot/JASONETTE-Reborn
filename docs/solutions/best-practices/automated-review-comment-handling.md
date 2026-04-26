---
title: "Handling automated code review comments across multiple bots"
date: 2026-03-31
category: best-practices
module: Development Workflow
problem_type: best_practice
component: development_workflow
applies_when: "PRs reviewed by Gemini, Copilot, CodeRabbit, or other automated reviewers"
severity: medium
tags: [code-review, gemini, copilot, coderabbit, github, pr-workflow, automation]
---

# Handling Automated Code Review Comments Across Multiple Bots

## Context

Modern PRs are reviewed by multiple automated bots simultaneously. Each bot has different comment structures, API behaviors, and approval workflows. This session managed 21+ comments from 3 bots across 4 parallel PRs — the patterns below emerged from that experience.

## Guidance

### Comment locations differ by bot

| Bot | Inline comments | Review body | Issue comments |
|-----|----------------|-------------|----------------|
| **Gemini** | Yes (line-level) | Summary only | Summary |
| **Copilot** | Yes (line-level) | Summary only | None |
| **CodeRabbit** | Yes (actionable) | **Nitpicks nested inside** `<details>` blocks | Summary + rate limit warnings |

**Critical:** CodeRabbit nests nitpick comments and out-of-diff findings inside its review body's `<details><summary>Nitpick comments</summary>` section. These are NOT separate API entities. You must read the full review body text to find them — `gh api repos/.../pulls/{pr}/comments` won't show them.

### Reply APIs

```bash
# Inline review comments — reply to specific comment
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  -f body='Fixed in {sha}.'

# Review body nitpicks — reply as issue-level comment
gh pr comment {pr} --body 'Re: CodeRabbit nitpick on X: ...'
```

### Every deferred item needs a tracked todo

When replying "will address in follow-up" or "deferred to next pass", create a corresponding todo file:

```bash
# Bad: reply without tracking
"Will deduplicate in follow-up."  # Where? When? Who tracks it?

# Good: reply + todo
"Known duplication. Created todo #019 for follow-up."
# + todos/019-ready-p3-extract-shared-style-resolution.md exists
```

Push each todo to the correct branch — not all to main.

### CodeRabbit approval workflow

CodeRabbit's `CHANGES_REQUESTED` state persists even after pushing fixes. To flip to `APPROVED`:
1. Push the fix commit
2. Comment `@coderabbitai resolve` on the PR
3. Wait ~30s for re-evaluation

CodeRabbit rate-limits when multiple PRs are pushed simultaneously. It will review the first and return "Rate limit exceeded" on the rest. Wait for the cooldown, then trigger manually with `@coderabbitai review`.

A rate-limit summary is **not** a review. Do not describe a PR as CodeRabbit-reviewed or CodeRabbit-approved unless the bot submitted a formal review. If you merge while rate-limited, record the actual evidence instead, e.g. "CodeRabbit rate-limited; CI passed and an independent Codex xhigh/pi review found no blockers."

### Triage framework

| Severity | Action | Example |
|----------|--------|---------|
| P1 (bug/crash) | Fix immediately, reply with commit SHA | Hit-testing blocked by Color.clear |
| P2 (correctness) | Fix in same PR cycle, reply with SHA | Force unwraps → if-let bindings |
| P3 (nit/style) | Create todo, reply with rationale + todo number | Extract shared helper |
| Declined | Reply with rationale, no todo | try! matches codebase convention |

## Why This Matters

- Unreplied comments signal abandoned PRs to reviewers and maintainers
- Deferred items without todos get lost — reviewers remember promises
- Different bots need different reply mechanisms — using the wrong API silently fails
- Rate limits on parallel PRs can block all reviews if not anticipated
- Review coverage can be overstated if rate-limit comments are treated as approvals

## When to Apply

- Any PR with automated reviewers enabled
- Especially when shipping multiple PRs simultaneously (rate limits compound)
- When using a swarm/parallel PR workflow

## Examples

### Recording a rate-limited PR honestly

```bash
# If CodeRabbit only posted a rate-limit issue comment, there may be no formal review
# body to read. Record that explicitly in the PR/handoff instead of implying approval.
gh pr view <pr> --json reviews,comments \
  --jq '{reviews: [.reviews[] | {author:.author.login,state}], comments: [.comments[] | select(.body | contains("Rate limit exceeded")) | .body[:120]]}'
```

### Finding nested CodeRabbit nitpicks

```bash
# Get the review body — nitpicks are inside <details> blocks
gh api repos/{owner}/{repo}/pulls/{pr}/reviews \
  --jq '.[] | select(.user.login == "coderabbitai[bot]" and (.body | length) > 100) | .body'
```

### Replying to all comments systematically

```bash
# 1. Get all inline comments
gh api repos/.../pulls/{pr}/comments \
  --jq '.[] | select(.in_reply_to_id == null) | "\(.id) [\(.user.login)] \(.body[:80])"'

# 2. Reply to each
gh api repos/.../pulls/{pr}/comments/{id}/replies -f body='Fixed in {sha}.'

# 3. Check review bodies for nested items
gh api repos/.../pulls/{pr}/reviews \
  --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body'

# 4. Reply to body-level items
gh pr comment {pr} --body 'Re: CodeRabbit nitpick: ...'
```

## Related Issues

- See also: [automated-review-triage-patterns.md](../integration-issues/automated-review-triage-patterns.md) — earlier triage patterns from the project revival
- Builds on learning #12 from [reviving-a-decade-old-cross-platform-project.md](../architecture-patterns/reviving-a-decade-old-cross-platform-project.md)
