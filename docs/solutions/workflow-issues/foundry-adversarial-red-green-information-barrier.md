---
title: "Foundry adversarial red/green requires a strict information barrier"
date: 2026-04-26
category: workflow-issues
module: Development Workflow
problem_type: workflow_issue
component: development_workflow
severity: high
applies_when:
  - "A task explicitly asks for Foundry, forge, or adversarial red/green development"
  - "Tests and implementation should be authored independently from a reviewed NLSpec"
  - "A reviewer or user says normal multi-model PR review is not the adversarial process"
  - "The orchestrator is tempted to inspect all artifacts and patch failures directly"
tags: [foundry, adversarial, red-green, information-barrier, nlspec, orchestration, workflow]
---

# Foundry Adversarial Red/Green Requires a Strict Information Barrier

## Context

This session initially misidentified the project's adversarial process as normal
PR hardening: implement a fix, open a PR, let CodeRabbit/Gemini/Codex review it,
triage comments, and merge when CI is green. That is useful, but it is not the
Foundry adversarial process.

Foundry's value comes from keeping test authoring and implementation separated.
The red side writes tests from the Definition of Done; the green side implements
from the How section. The orchestrator mediates without leaking red's private
information to green.

## Guidance

### Name the process mode first

Before starting a task, distinguish these workflows:

```text
Review-only PR hardening:
implement -> CI -> bot/model reviews -> triage -> fix -> merge

Foundry adversarial red/green:
reviewed NLSpec -> red tests from DoD -> green implementation from How -> mediated PASS/FAIL loop
```

Multi-model review can happen after implementation, but it is not a substitute
for red/green isolation.

### Preserve Foundry's core invariant

In adversarial mode:

- **Red** writes tests from the NLSpec's Definition of Done.
- **Green** implements from the NLSpec's How section.
- **Green must not see:**
  - red test code
  - assertion text
  - failure messages
  - stack traces
  - expected vs actual values
  - fixture details derived from red tests
  - the Definition of Done section
- **The orchestrator** runs tests and sends green only:

```text
test_name_a: PASS
test_name_b: FAIL
```

No assertion snippets. No expected values. No "here is why it failed" analysis
that reveals red's private test logic.

### Do not become the god-mode fixer

If red/green output does not converge, the orchestrator must not inspect the
tests, inspect the implementation, and directly patch both sides in the
adversarial context. That collapses the information barrier.

Instead:

1. Diagnose whether the NLSpec/contract is ambiguous.
2. If red is wrong or brittle, route filtered feedback to red without showing
   green's implementation.
3. If green is incomplete, route only test-name PASS/FAIL outcomes to green.
4. If the same failures repeat, pause and refine the spec or escalate.
5. Stop immediately on any barrier leak.

### Use provider delegation for isolation

Separate provider processes naturally help preserve context boundaries:

- Codex/Gemini/OpenCode worker for red test authoring.
- Different Codex/Gemini/OpenCode worker for green implementation.
- Optional third worker for barrier audit.

Package each prompt explicitly. Red receives shared model + Definition of Done.
Green receives shared model + How. Neither receives the other's private material.

## Why This Matters

The red/green workflow catches a different class of defects than normal code
review. Red tests written independently from the implementation are less likely
to encode the implementer's assumptions. If the orchestrator leaks red's tests or
failure details to green, green can accidentally or deliberately code to the test
rather than to the spec. The process then becomes expensive normal review while
pretending to be adversarial.

Review-only workflows are still useful. CodeRabbit, Gemini, Copilot, and Codex
xhigh caught real issues in this session. They should be treated as a later
review layer, not as Foundry's red/green mechanism.

## When to Apply

- Use **review-only PR hardening** for ordinary todos, small fixes, and follow-up
  PRs where information isolation is not required.
- Use **Foundry adversarial red/green** when a task starts from a reviewed
  NLSpec, when independent test authorship is the goal, or when the user asks
  for forge/foundry/adversarial workflow.
- If unsure, ask which process mode is intended before writing tests or code.

## Examples

### Bad: calling review-only work adversarial

```text
I implemented the fix, opened a PR, read CodeRabbit/Gemini comments, ran Codex
xhigh, fixed findings, and merged. Therefore I followed the adversarial process.
```

This is multi-review PR hardening. It has no red/green information barrier.

### Good: Foundry red/green loop

```text
Process mode: Foundry adversarial red/green
Red input: shared data model + Definition of Done
Green input: shared data model + How
Forbidden leaks: red tests, assertions, failure messages, expected/actuals, DoD
Feedback to green: test names with PASS/FAIL only
Iteration count: 2
Barrier status: preserved
```

### Good: review-only declaration

```text
Process mode: review-only
Rationale: small Android test compile fix; no independent NLSpec/test authoring requested
Review layers: CodeRabbit, Gemini, Codex 5.5 xhigh via pi
```

## Related

- `~/.codex/skills/foundry-adversarial/SKILL.md` — canonical local Foundry adversarial workflow.
- `~/.codex/skills/foundry-forge/SKILL.md` — full research → spec → NLSpec → adversarial pipeline.
- [`multi-model-review-coderabbit-plus-codex-xhigh.md`](../best-practices/multi-model-review-coderabbit-plus-codex-xhigh.md) — complementary review-only second-pass practice.
- [`automated-review-comment-handling.md`](../best-practices/automated-review-comment-handling.md) — bot comment triage after or outside adversarial implementation.
