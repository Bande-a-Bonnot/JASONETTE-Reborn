---
title: "Parallel PR swarm pattern with git worktrees"
date: 2026-03-31
category: best-practices
module: Development Workflow
problem_type: best_practice
component: development_workflow
applies_when: "Shipping 3+ independent code changes that touch overlapping files"
severity: medium
tags: [git, worktrees, parallel-development, swarm, merge-conflicts, ci-cd]
---

# Parallel PR Swarm Pattern with Git Worktrees

## Context

When shipping multiple independent fixes that touch overlapping files (like `JasonDocument.swift` and `JasonStyleModifier.swift`), sequential development wastes time. Each PR waits for the previous to be reviewed and merged before the next can start. Git worktrees enable true parallel development — each agent works in an isolated copy of the repo on its own branch.

## Guidance

### Setup: Launch parallel agents in worktrees

```
Agent(isolation: "worktree", prompt: "Branch: fix/feature-a. Implement unit A only...")
Agent(isolation: "worktree", prompt: "Branch: fix/feature-b. Implement unit B only...")
```

Each agent gets its own working directory and branch. They can't interfere with each other.

### Critical: Scope isolation in agent prompts

Explicitly tell each agent to implement ONLY its assigned unit. Without this, agents will independently duplicate adjacent work they see in the plan — this session had 2 of 4 agents independently add body background code that belonged to a different PR.

### Post-completion checklist

1. Verify each branch has exactly 1 commit ahead of main: `git log <branch> ^main`
2. Check no agent committed to main: `git log --oneline main -3`
3. If an agent committed to main, move the branch pointer and reset: `git branch -f <branch> <commit> && git reset --hard <previous-main>`
4. If agents duplicated code, amend their commits to remove it, then rebase onto clean main
5. Clean up worktrees: `git worktree remove .claude/worktrees/<agent> && git worktree prune`

### Merge strategy

Merge the PR that touches the fewest shared files first. When the last PR has conflicts (inevitable with overlapping files), all conflicts will be additive — include both sets of new fields/tests/methods.

## Why This Matters

- **4x throughput**: 4 PRs shipped in ~5 minutes vs ~20 minutes sequential
- **Better reviews**: Each PR is small, focused, independently testable
- **Mechanical conflicts**: Additive changes to the same struct/file resolve trivially
- **Risk isolation**: If one PR has issues, the others aren't blocked

## When to Apply

- 3+ independent changes that could each be a separate PR
- Changes are additive (new fields, new methods, new test blocks) not conflicting
- Each change has its own test suite
- Time-to-merge matters more than perfect git history

## Examples

### What went wrong and how to fix it

```bash
# Agent committed to main instead of its branch
git log --oneline main -3
# abc1234 fix: body background (WRONG — should be on branch)
git branch -f fix/body-background abc1234
git reset --hard previous-main-sha

# Agents duplicated code from another PR's scope
git checkout fix/feature-b
# Remove duplicated code, amend
git add -A && git commit --amend --no-edit
# Rebase to remove the leaked parent commit
git rebase --onto main leaked-commit-sha
git push --force-with-lease origin fix/feature-b
```

### Merge conflict resolution (additive)

```swift
// Both PRs add fields to the same struct — include both
<<<<<<< HEAD
    top: other.top ?? self.top,
    right: other.right ?? self.right,
=======
    opacity: other.opacity ?? self.opacity
>>>>>>> fix/styles

// Resolution: include all fields
    top: other.top ?? self.top,
    right: other.right ?? self.right,
    opacity: other.opacity ?? self.opacity
```

## Related Issues

- See also: [reviving-a-decade-old-cross-platform-project.md](../architecture-patterns/reviving-a-decade-old-cross-platform-project.md) — Section 17 (parallel work while waiting for reviews)
- PRs #13, #14, #15, #16 (Phase A renderer foundations)
