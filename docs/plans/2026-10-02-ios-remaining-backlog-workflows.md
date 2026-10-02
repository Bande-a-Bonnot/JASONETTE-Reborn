# Remaining iOS backlog workflows

Status: complete for 106–108 — 2026-10-02

Baseline: elevated `swift test --jobs 2 --quiet` passed 622/622 before product
edits on 2026-10-02. Only one root-owned SwiftPM process ran.

## Authorization and models

The user requested a workflow for each of the three open todos, using
GPT-6.1 Sol with high or xhigh effort, and explicitly requested xhigh reviewers
for every task. Each workflow runs plan → focused regression → implementation
→ independent review → simulator acceptance → completion record.

| Workflow | Canonical todo | Planning and implementation | Independent review |
| --- | --- | --- | --- |
| 106 | `todos/106-complete-p2-ios-html-row-href-navigation.md` | GPT-6.1 Sol xhigh | GPT-6.1 Sol xhigh |
| 107 | `todos/107-complete-p2-ios-default-text-contrast-in-dark-appearance.md` | GPT-6.1 Sol xhigh | GPT-6.1 Sol xhigh |
| 108 | `todos/108-complete-p3-ios-media-picker-cancel-feedback.md` | GPT-6.1 Sol high | GPT-6.1 Sol xhigh |

Read the canonical todo and `docs/HANDOFF.md` independently. Its definition of
done is the acceptance contract. Record the diagnosis, intended change, owned
files, meaningful regression cases, and simulator steps in the task plan:
`docs/plans/2026-10-02-ios-todo-NNN-plan.md`.

## Coordination

- The root owns integration, local commits, tests, build/simulator access,
  acceptance screenshots, todo statuses, this workflow record, and handoff.
- Workers first write their task plan and report the proposed file list.
  Wait for the root's implementation dispatch after ownership is reconciled.
- Shared checkout: edit only approved files. Workers do not stage, commit,
  revert, change branches, launch other agents, or alter other tasks' changes.
- `ComponentRegistry.swift` is a shared boundary. The root assigns or applies
  changes there sequentially after the planning stage; workers request any
  needed expansion of their scope.
- Initial likely boundaries: 106 HTML component and navigation regression;
  107 default text/input appearance, rendering context, appearance regression;
  108 action dispatcher and action-chain regression. Confirm them from source.
- Preserve pre-existing `AGENTS.md`/`CLAUDE.md` edits and the two untracked
  July arbiter JSON files. Limit work to the iOS renderer and task evidence.
- Keep model usage bounded: one worker per task and one independent review per
  task, with a focused follow-up only to repair a concrete finding.
- Root grants one test lease at a time. SwiftPM runs with `--jobs 2`; Xcode
  builds use `-jobs 2`. Workers do not start tests/builds/simulator work without
  the lease. Research and independent source edits may run concurrently.
- No todo closes until its source review, tests, and actual iOS acceptance pass.

## Acceptance paths

106: reproduce through normal Home → Tutorial → Web Container navigation;
diagnose tap routing versus URL/load failure, open SVG Clock and a second HTML
menu destination, go back, and preserve internal interaction without outer href.

107: choose a consistent default-color policy that respects authored colors;
verify heading, placeholder and entered text in light/dark appearance, including
focus, secure text and related textarea behavior. Restore light appearance.

108: cancel the native picker and return without generic failure feedback when
there is no authored error continuation; prove the authored error continuation
still runs, success/share and media state do not advance, and real failures
retain feedback.

## Platform prerequisites

The existing iOS app already uses WebKit and native media pickers. Project.swift
contains camera, photo-library and microphone usage descriptions. No new SDK,
portal, secret, entitlement, or capability is expected for these fixes. Workers
must confirm their actual change fits those existing prerequisites and flag any
new requirement before implementation. Root verifies the fresh simulator build
and real menu/picker behavior after integration.

Use the QA workflow in `docs/qa/README.md`. The retained iPhone 17 Pro/iOS 26.2
device is `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB`; it was shut down after the
previous pass. All simctl/agent-device operations require elevated host access
and consistent explicit state/session arguments. New session IDs must be UUIDv7.

## Completion records

Each task records its review findings and resolutions, exact test results,
final build source, simulator actions, and evidence in its task plan and a QA
report. Root updates the three todos and `docs/HANDOFF.md` after verification.


Final source `246d168`; final full suite **679 passed**, fresh iOS build and
all three native acceptance paths pass. Independent xhigh findings were repaired
and reviewed clean. Evidence, source provenance, and cleanup are recorded in
[the QA report](../qa/2026-10-02-ios-backlog-verification.md). All three todos
are complete. New preexisting toolbar duplication is queued separately as
[todo109 workflow](2026-10-02-ios-todo-109-workflow.md), with high planning and
implementation and xhigh review. No implementation has started for109.
