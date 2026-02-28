---
title: "Triage patterns for automated code review comments"
category: integration-issues
tags: [code-review, gemini, automated-review, pr-workflow, github]
module: JASONETTE-Reborn
symptom: "Automated reviewers (Gemini, Greptile, Copilot) flood PRs with findings of varying severity and relevance, slowing down merge velocity"
root_cause: "No systematic triage process for classifying and responding to automated review comments"
---

# Triage patterns for automated code review comments

## Problem

Each PR in the Jasonette Revival project triggers automated code reviews
from Gemini (and potentially Greptile, Copilot). These reviewers generate
a mix of genuine bugs, valid improvements, intentional design choices, and
out-of-scope suggestions — all presented with equal urgency.

PR #5 (Android) received 10 Gemini comments: 2 critical, 4 high, 4 medium.
Without a systematic approach, addressing them efficiently becomes a
bottleneck.

## Observations from PRs #1 through #7

### Critical findings are usually real

Gemini flagged two genuine bugs:

- **`ClassCastException` risk** from unsafe `JsonElement.jsonPrimitive`
  access — a real crash path when JSON values are objects or arrays
  instead of primitives.
- **`ViewModel` requiring `Context`** but not receiving it — a real
  initialisation failure.

Both required immediate fixes.

### High-priority findings are mixed

Some were correct:

- BOM version `2024.12.01` flagged as potentially invalid — it was.
  Changed to `2024.06.00`.
- Redundant casts flagged — simplified the code.

Others were overly cautious and did not warrant changes.

### Medium-priority findings may be intentional

- "Hardcoded URL" for the demo entry point — this was the intentional
  design for a default demo app.
- "Use OkHttp instead of HttpURLConnection" — valid suggestion but out
  of scope for the current milestone.

### Post-merge findings are valuable

Gemini found the tree/blob URL issue on PR #6 *after* it had already been
merged. This was subsequently addressed in PR #7. Late reviews should not
be ignored just because the code has already landed.

## Solution: systematic triage

Classify every comment before acting on it:

```
For each comment:
  1. Read the finding
  2. Classify:
       genuine-bug         → real defect, crashes or incorrect behaviour
       valid-improvement   → correct suggestion, better code
       intentional-design  → works as designed, reviewer lacks context
       out-of-scope        → valid but belongs in a future milestone
  3. Act:
       genuine-bug         → fix immediately, commit
       valid-improvement   → fix if trivial, create a todo if substantial
       intentional-design  → reply explaining the design decision
       out-of-scope        → acknowledge, note for future work
  4. Reply to EVERY comment
```

### Why reply to every comment

Automated reviewers track unresolved comments. Ignoring a comment means
it may resurface on the next push, cluttering subsequent reviews. A short
reply — even "Acknowledged, out of scope for this PR" — marks the thread
as addressed and prevents re-flagging.

### Replying via the GitHub API

For bulk triage, replying through the CLI is faster than the web UI:

```bash
# Reply to a specific review comment
gh api repos/OWNER/REPO/pulls/PR/comments \
  -f body="Addressed: [explanation]" \
  -F in_reply_to=COMMENT_ID
```

To list all pending review comments on a PR:

```bash
gh api repos/OWNER/REPO/pulls/PR/comments --jq '.[].id'
```

## Key Insights

1. **Severity labels from automated reviewers correlate with real risk.**
   Critical findings were correct 100% of the time across PRs #1-#7.
   High findings were correct roughly half the time. Medium findings were
   more often intentional or out of scope.

2. **Treat automated reviews as a checklist, not a conversation.**
   Read, classify, act, reply. Do not deliberate on each one individually —
   batch them by classification and process each batch.

3. **Post-merge reviews catch what pre-merge reviews miss.** Monitor
   comments that arrive after a merge. They represent findings on the
   final state of the code that earlier review rounds could not see.

4. **Replying is not optional.** Every unanswered comment is technical
   debt in your review workflow. Automated reviewers will carry forward
   unresolved threads.
