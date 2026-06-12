---
id: "019eb90b-2651-7cc3-bb7a-c53ca990e84c"
status: open
priority: p3
issue_id: "065"
tags: [qa, ios, simulator, agent-device, tooling]
dependencies: []
---

# Stabilize agent-device iOS snapshot QA workflow

## Problem Statement

During the 2026-06-11 iOS Simulator UI QA pass, `agent-device open` could attach
to the Debug app but `agent-device snapshot` repeatedly timed out. Follow-up on
2026-06-12 narrowed this to an `agent-device` iOS XCTest runner startup/handshake
problem, not an app launch problem: pinned raw `xcrun simctl launch` succeeds for
`com.bande-a-bonnot.jasonette`, and `agent-device prepare ios-runner` can succeed
when given a longer timeout, while `agent-device open` still has a hard 90s daemon
request timeout in agent-device 0.17.2 and can time out before establishing an
active app session.

The pass still captured visual evidence with `simctl io screenshot`, but the
timeout prevented interactive tap/scroll/text-entry automation for action chains,
inputs, share sheets, and snapshot pull-to-refresh flows.

This is an environment/tooling issue rather than an app defect, but it reduces
the reliability of future exploratory UI QA.

## Current Diagnosis

2026-06-12 follow-up evidence:

- `npx --yes agent-device@latest --version` — 0.17.2.
- Two simulators were booted, so all checks pinned the iPhone 17 Pro UDID
  `61EA0147-56E4-4399-8D51-F98A93B708A6`.
- Raw launch succeeds:
  `xcrun simctl launch --terminate-running-process 61EA0147-56E4-4399-8D51-F98A93B708A6 com.bande-a-bonnot.jasonette`
  returned a process id.
- `agent-device prepare ios-runner --platform ios --device "iPhone 17 Pro" --timeout 240000`
  timed out at the daemon request layer.
- `agent-device prepare ios-runner --platform ios --device "iPhone 17 Pro" --timeout 360000`
  with a fresh state dir succeeded in ~166s (`Prepared Apple runner: iPhone 17 Pro`).
  This shows the runner can build/start/health-check if the prepare command gets
  enough wall-clock budget.
- `agent-device open` in 0.17.2 does not expose a command-level `--timeout` flag.
  After the successful extended prepare, `agent-device open ... --state-dir <same>`
  still hit its fixed 90s daemon request timeout; a following `snapshot -i` failed
  with `SESSION_NOT_FOUND` because `open` never established an active app session.
  Although `prepare ios-runner --help` mentions `clean:daemon`, the installed
  0.17.2 command list does not expose a `clean:daemon` command. It does expose
  `disconnect [--shutdown]` for remote daemon state / lease cleanup. Running
  `disconnect` against the prepared local state reported `No remote connection`,
  and a subsequent `open` still hit the same 90s daemon request timeout.
- `agent-device open ... --debug` with the default state dir first failed a
  cached runner health check: `Runner did not accept connection`, then attempted
  forced rebuild and reported `xcodebuild build-for-testing failed` after the
  daemon request timed out.
- `agent-device open ... --state-dir /tmp/agent-device-jasonette065-state --debug`
  built a fresh runner (`** TEST BUILD SUCCEEDED **`) but the 90s `open` daemon
  timeout interrupted the subsequent `test-without-building` runner handshake
  (`** BUILD INTERRUPTED **`, `ios_runner_connect attempt_failed`, then
  `request canceled`).
- A warm retry with the same temp state also timed out in `ios_runner_connect`.
- `agent-device open ... --no-device-hub` with a fresh state dir did not help:
  it reused the runner, exhausted `ios_runner_connect`, invalidated/cleaned the
  cache, then started a rebuild that the same 90s daemon timeout interrupted.
- A second booted simulator (iPhone SE UDID
  `A9CEAA75-883C-48DB-BDDD-E6A360DE8136`) also launched Jasonette successfully
  via raw `simctl` after installing the app, but `agent-device open` still timed
  out before runner handshake. This makes an app install/launch failure unlikely.

Persistent diagnostic summary:

- `docs/qa/artifacts/2026-06-11-ui-qa-queue-run/agent-device-065-diagnostics.md`

Key logs:

- `/Users/thomas/.agent-device/sessions/jasonette065/requests/25d0ace11d67cbae.ndjson`
- `/Users/thomas/.agent-device/sessions/jasonette065/runner.log`
- `/tmp/agent-device-jasonette065-state/sessions/jasonette065/requests/b379716b459b925d.ndjson`
- `/tmp/agent-device-jasonette065-state/sessions/jasonette065/runner.log`
- `/tmp/agent-device-jasonette065-state/sessions/jasonette065b/requests/3af03016d1e9660e.ndjson`
- `/tmp/agent-device-jasonette065-nodevicehub/sessions/jasonette065c/requests/9198f8c530afb785.ndjson`
- `/tmp/agent-device-jasonette065-nodevicehub/sessions/jasonette065c/runner.log`
- `/tmp/agent-device-jasonette065-se/sessions/jasonette065se/requests/ae36b7d31b82479a.ndjson`
- `/tmp/agent-device-jasonette065-se/sessions/jasonette065se/runner.log`
- `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep/requests/8ae1d72f2bec1e7c.ndjson`
- `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep/runner.log`
- `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep/requests/03e2bf102c409e08.ndjson`
- `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep/requests/85593851521adcc2.ndjson`
- `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep2/requests/baf8cacad263a6de.ndjson`

## Acceptance Criteria

- [x] Reproduce or clear the timeout on the standard iPhone 17 Pro/iOS 26.2 QA
      simulator.
- [ ] Identify a reliable recovery path for `agent-device open` after extended
      `prepare ios-runner`, or document an upstream/tooling blocker if no local
      recovery exists.
- [ ] Document the working recovery path in `docs/qa/README.md` if extra setup,
      longer timeouts, runner reset, or device cleanup is required.
- [ ] Complete a short interactive smoke using `agent-device snapshot` plus at
      least one `press`/navigation step.
- [ ] Capture or link evidence from the successful interactive smoke.

## Verification Guidance

- Run the documented `agent-device` workflow from `docs/qa/README.md` against
  the installed Debug app, pinning the iPhone 17 Pro UDID when multiple
  simulators are booted.
- Start with `prepare ios-runner --timeout 360000`; the shorter default/240s path
  may fail before the runner is ready on this machine.
- Confirm `open` establishes an active app session before attempting `snapshot -i`.
- Confirm `snapshot -i` returns accessibility refs without repeated timeouts.
- Press at least one visible control, re-snapshot, and capture a supporting
  screenshot under `docs/qa/artifacts/`.
