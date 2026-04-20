---
title: "Disciplined /loop mode for long-running PR-babysit sessions"
date: 2026-04-19
category: best-practices
module: JASONETTE-Reborn
problem_type: best_practice
component: development_workflow
severity: medium
applies_when:
  - "Running Claude Code's dynamic /loop to babysit a PR across multiple review cycles"
  - "Using Monitor and ScheduleWakeup together to react to GitHub Actions, review bots, or other long-running signals"
  - "Polling gh api / gh run list from inside a looped session"
tags: [loop, monitor, schedulewakeup, pr-workflow, prompt-caching, gh-cli, claude-code]
---

# Disciplined /loop mode for long-running PR-babysit sessions

## Context

Claude Code's dynamic `/loop` mode (the `loop` skill, invoked as `/loop <prompt>`
with no interval so the model self-paces) is the right tool for babysitting a
PR through several review cycles: CI runs, CodeRabbit / Codex reviews, human
comments, re-pushes. The loop stays alive across cycles and combines two
wake primitives — `Monitor` (event-driven, tails a command and pushes
notifications when a line matches a filter) and `ScheduleWakeup` (time-based,
reinvokes the session after N seconds).

During PR #20 review cycles in this repo, several failure modes in the
primitives surfaced that turn a loop from "cheap and reliable" into
"expensive and silently stuck." This doc captures the rules learned.

## Guidance

### 1. Monitor filters must cover every terminal state — silence is not success

A `Monitor` grepping only for success will go silent on failure, cancellation,
or a crashloop. Silent is indistinguishable from "still running," so the loop
never wakes and never reacts. Always widen the filter to an alternation over
every terminal state you'd act on.

```bash
# Bad — silent on failure/cancellation; can't tell "still running" from "failed"
gh run watch <id> --exit-status | grep 'completed/success'

# Good — the filter used in the PR #20 GH Actions watcher
gh run list --json status,conclusion --jq '.[] | "\(.status)/\(.conclusion)"' \
  | grep -E 'completed/success|completed/failure|completed/cancelled'
```

Rule of thumb: if the filter can't distinguish "still running" from "terminal
but not matched," it's wrong.

### 2. Cache-TTL discipline for ScheduleWakeup

Anthropic's prompt cache TTL is 5 minutes. Picking a wakeup delay near that
boundary is the worst of both worlds — you pay a cache miss (full prompt
re-read) without amortizing the wait across a meaningful interval.

Pick one of two regimes:

- **Active watch** — `ScheduleWakeup` delays **under 270s** (~4m30s) stay
  inside the cache window. Use when the loop itself is the primary wake
  signal and you expect frequent reinvocation.
- **Fallback heartbeat** — `1200s`–`1800s` (20–30m). One cache miss buys a
  long, cheap wait. Use when a `Monitor` is the primary wake and
  `ScheduleWakeup` is only a safety net.

**Never use `300s`** — it's the dead zone: cache miss guaranteed, wait too
short to amortize.

### 3. Split roles: Monitor is primary, ScheduleWakeup is the safety net

If a `Monitor` is tailing the real event stream (CI conclusions, PR review
bot comments), `ScheduleWakeup` should not also be polling the same signal.
That's double-polling — two wakeups for one event, duplicate API load,
duplicate reasoning work.

- `Monitor` → wakes on real events (low latency, event-driven)
- `ScheduleWakeup` → long-interval fallback so the loop can't silently die
  if the `Monitor` crashes or its filter misses a state

### 4. Kill stale Monitors before arming a replacement

When a `Monitor` is restarted — e.g. after fixing a filter bug — the old one
is still running. Two `Monitor`s watching the same state generate duplicate
notifications and double the poll load on GitHub's API. Before arming a new
watcher:

1. `TaskList` — enumerate live background tasks
2. `TaskStop <old_id>` — kill the stale monitor (e.g. `bzovnuyyw`,
   `b6yu46xcq` from this session)
3. `Monitor <new command>` — arm the replacement

### 5. Cross-check repo owners — `gh api` typos are silent 404s

`gh api repos/<owner>/<repo>/...` returns a `404` when the owner or repo
slug is wrong, and `gh` surfaces it as an empty JSON result — which is
indistinguishable from "no results yet." In this session, a typo like
`Banade-a-Bonnot` vs the correct `bande-a-bonnot` silently produced empty
CI data for a full poll cycle. Always verify the owner once per session
(e.g. `gh repo view --json nameWithOwner`) before trusting empty responses.

## Why This Matters

A `/loop` session that wakes when it shouldn't, or doesn't wake when it
should, either burns tokens or misses the signal it was set up to catch.
The four primitives (`Monitor`, `ScheduleWakeup`, `TaskList`, `TaskStop`)
are small, but their interactions compound:

- A bad `Monitor` filter + a 300s `ScheduleWakeup` fallback = cache miss
  every wake, plus silent failure on any non-success terminal state.
- Stale `Monitor`s = duplicate API polls, GitHub secondary rate limits,
  duplicate model reasoning on the same event.
- A `gh api` typo behind all of this = the whole loop "works" but watches
  nothing.

Getting these right turns PR babysitting from an expensive foreground task
into a cheap background job.

## When to Apply

- Any `/loop` session spanning more than one CI run or review cycle
- Anywhere `Monitor` and `ScheduleWakeup` appear in the same session
- When restarting a watcher after fixing its command or filter
- Before trusting an empty `gh api` response to mean "nothing yet"

## Examples

**Terminal-state-complete Monitor filter (from PR #20 review loop):**

```bash
Monitor: gh run list --repo bande-a-bonnot/JASONETTE-Reborn \
  --branch refactor/tab-navigation-step-1-scaffolding \
  --json status,conclusion --jq '.[] | "\(.status)/\(.conclusion)"'
Filter: completed/success|completed/failure|completed/cancelled
```

**Cache-safe wakeup regimes:**

```
# Active watch — stays inside 5m cache window
ScheduleWakeup 240s

# Fallback heartbeat — one miss, long amortization
ScheduleWakeup 1500s

# Dead zone — don't
ScheduleWakeup 300s   # ❌ cache miss + no amortization
```

**Stale-Monitor cleanup before re-arming:**

```
TaskList
→ bzovnuyyw  Monitor  gh run list ...  (running, stale filter)
→ b6yu46xcq  Monitor  gh run list ...  (running, stale filter)

TaskStop bzovnuyyw
TaskStop b6yu46xcq
Monitor <new command with corrected filter>
```

## Related

- `docs/solutions/integration-issues/automated-review-triage-patterns.md` —
  how to triage the review comments the loop surfaces
- `docs/solutions/best-practices/automated-review-comment-handling.md`
- `docs/solutions/best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md`
