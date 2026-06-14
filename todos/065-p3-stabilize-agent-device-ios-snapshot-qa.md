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

2026-06-13 follow-up evidence:

- `agent-device@latest` is now 0.17.3. After pinning the iPhone 17 Pro UDID,
  shutting down the second booted simulator, killing stale `agent-device`/
  `xcodebuild`/runner processes, and moving aside `~/.agent-device/ios-runner/derived`,
  `prepare ios-runner --timeout 600000` still failed.
- The 0.17.3 failure is no longer a build-cache failure: `** TEST BUILD SUCCEEDED **`
  appears, then the `test-without-building` runner never accepts HTTP commands.
  `ios_runner_connect` exhausts after 90s with `Runner did not accept connection`
  and reason `IOS_RUNNER_CONNECT_TIMEOUT`. The saved `runner.log` shows the
  `xcodebuild test-without-building -only-testing ... RunnerTests/testCommand`
  invocation, but no `Test Suite` / `Test Case` start lines and no HTTP/listen/server
  port-bind output before `** BUILD INTERRUPTED **`.
- During one retry, stale runner-bundle cleanup also logged
  `ios_runner_startup_cleanup_stale_bundle_failed` because `xcrun` timed out
  after 10s uninstalling `com.callstack.agentdevice.runner.uitests.xctrunner`.
- Raw CoreSimulator checks remained responsive after the failed runner attempts:
  `simctl list devices booted` and `get_app_container` each completed in ~2s,
  and `simctl launch --terminate-running-process ... com.bande-a-bonnot.jasonette`
  completed in ~12s with a process id. This keeps the diagnosis focused on the
  agent-device XCTest runner/session handshake rather than Jasonette install or
  basic simulator launch.
- `agent-device@0.14.9` is not a viable local recovery: it predates
  `prepare ios-runner`, and its pinned `open ... --relaunch --debug` path still
  hit the same fixed 90s daemon request timeout.
- Post-cleanup state check: moved-aside runner caches were removed, the active
  derived cache is empty, and `agent-device@latest session list` against the
  cleaned temp state returned `"sessions": []`.
- Narrowed next step: investigate the generated XCTest runner invocation, not
  Jasonette app logs. Compare the two 0.17.3 `test-without-building` attempts
  and their generated `.xctestrun` files, especially session/port environment,
  test bundle/app paths, and destination. Then inspect the 0.17.3 runner source
  around `RunnerTests.testCommand` / transport startup to determine whether
  XCTest never launches the test or the test hangs before binding/logging its
  HTTP command server.

2026-06-14 follow-up evidence:

- `agent-device@latest` advanced to 0.17.4 in the same npx cache path
  `/Users/thomas/.npm/_npx/d03929938e601151/node_modules/agent-device`.
- Manual `.xctestrun` inspection showed the runner does accept
  `AGENT_DEVICE_RUNNER_PORT=...` as a command-line argument through
  `RunnerEnv.resolvePort()`. A temporary local patch to the cached 0.17.4
  package added those argv entries during `.xctestrun` generation; the package
  was restored afterward to its original SHA-256
  `5dcb3e8f11788ea76860cad090ed63ebd064d9a26a8a1ce20bdb0f1cffc05371`.
- With that temporary patch, `prepare ios-runner --timeout 600000` succeeded:
  the runner reached `Test Suite`, logged `AGENT_DEVICE_RUNNER_DESIRED_PORT`,
  `AGENT_DEVICE_RUNNER_LISTENER_READY`, and accepted a shutdown command. This
  proves the runner can start and bind on this host in that patched path when the
  command has enough wall-clock budget; it is not a verified unpatched 0.17.4
  recovery run.
- A subsequent patched `open` in the same state/session still failed. The
  `prepare` invocation had shut down its runner, so `open` launched a fresh
  `test-without-building` run. That fresh run used only the built-in ~45s runner
  health/startup window, failed `prepare_cached_runner_health_failed`, cleaned
  the cached artifact, started a rebuild, and then hit `open`'s fixed 90s daemon
  request timeout before establishing an app session. No unpatched 0.17.4
  `open`/`snapshot` recovery was verified after restoring the cache.
- Updated diagnosis: the blocker is no longer explained as purely missing port
  propagation. The local CLI path has two separate timing/lifecycle issues:
  `prepare` does not leave an active runner/app session usable by a later
  one-shot `open`, while `open` itself has no exposed timeout/startup-budget flag
  and can kill the runner before XCTest reaches `RunnerTests.testCommand`.

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
- `/tmp/agent-device-jasonette065-clean-v0173/sessions/jasonette065clean/requests/43ebf35046665cfe.ndjson`
- `/tmp/agent-device-jasonette065-clean-v0173/sessions/jasonette065clean/runner.log`
- `/Users/thomas/.agent-device/logs/jasonette065v0149open/2026-06-13/2026-06-13T15-27-11-978Z-mqcibzy0-81a8d5b8.ndjson`
- `/tmp/agent-device-jasonette065-v0149-open/daemon.log`
- `/tmp/agent-device-jasonette065-0174-argpatch/sessions/jasonette0650174argprep/requests/d40c09c68bf290c9.ndjson`
- `/tmp/agent-device-jasonette065-0174-argpatch/sessions/jasonette0650174argprep/requests/2dd0483cfe49bf71.ndjson`
- `/tmp/agent-device-jasonette065-0174-argpatch/sessions/jasonette0650174argprep/runner.log`

## Acceptance Criteria

- [x] Reproduce or clear the timeout on the standard iPhone 17 Pro/iOS 26.2 QA
      simulator.
- [x] Identify a reliable recovery path for `agent-device open` after extended
      `prepare ios-runner`, or document an upstream/tooling blocker if no local
      recovery exists. Current outcome: no reliable local recovery; documented as
      an `agent-device` XCTest runner/session handshake blocker.
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
- Before another full `agent-device open`/`snapshot` retry, find a way to give
  `open` the same extended runner startup budget as `prepare`, or run through a
  single long-lived daemon/session path that does not shut the prepared runner
  down before `open`.
- Confirm `snapshot -i` returns accessibility refs without repeated timeouts.
- Press at least one visible control, re-snapshot, and capture a supporting
  screenshot under `docs/qa/artifacts/`.
