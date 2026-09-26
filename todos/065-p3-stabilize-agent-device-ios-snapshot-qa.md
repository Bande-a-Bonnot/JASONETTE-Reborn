---
id: "019eb90b-2651-7cc3-bb7a-c53ca990e84c"
status: complete
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

### 2026-09-26 interactive recovery verified

The temporary simulator from the September 25 attempt reached SpringBoard by
the next session. Screenshots returned promptly, the existing Debug app
installed, and unmodified `agent-device` 0.21.12 successfully prepared its
runner with `--timeout 240000`. `open --timeout 120000`, `snapshot -i`, and
screenshots then succeeded. Luna navigated Home → Core → `$href`, pushed the
authored self-link, and returned using the app's back control. Subsequent
interaction commands completed in roughly 1–5 seconds.

All CLI commands must use elevated host access and the same explicit
`--state-dir` and `--session`. During handover, a sandboxed screenshot call
mistook the daemon for an unreachable process and removed its metadata.
Reopening without relaunch, preparing the runner again with a 240-second
budget, and keeping every subsequent call elevated recovered the session.

The working context requirements are documented in `docs/qa/README.md`.
Exact environment values and the exploration charter are in
`docs/plans/2026-09-26-ios-luna-exploratory-qa-plan.md`; journey evidence is in
`docs/qa/2026-09-26-ios-luna-exploratory-qa.md`, with Home and Core screenshots
under `docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/`.
The earlier CoreSimulator migration failure's cause was not established;
this closes the interactive smoke requirement based on the recovered device.

### Historical investigations

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

### 2026-09-25 retry: agent-device 0.21.12 and CoreSimulator migration

The planned whole-app navigation pass used `agent-device` 0.21.12 from
`/private/tmp/jasonette-agent-device-0.21.12/node_modules/.bin/agent-device`,
with state directory
`/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc`
and UUIDv7 session `01a0d8fc-d8a1-7381-b687-04a62d5892cc`.

- `prepare ios-runner --platform ios --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 --state-dir /private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc --timeout 600000 --debug` built the XCTest runner successfully. `test-without-building` then emitted repeated `IDERunDestination: Supported platforms for the buildables in the current scheme is empty` warnings and repeated `ios_runner_connect` failures. The final request had `sessionReady:false` / `request canceled`; prepare timed out at 630 seconds.
- The original iPhone 17 Pro simulator `61EA0147-56E4-4399-8D51-F98A93B708A6` returned terminal `Status=3, isTerminal=YES, Elapsed=00:51. Data Migration Failed` from `xcrun simctl bootstatus <UDID> -b`. Its screenshot showed a black boot screen with a centered spinner.
- A replacement iPhone 17 Pro simulator `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB` reached terminal `Status=3, isTerminal=YES, Elapsed=17:02. Data Migration Failed`. Capturing its screenshot hung for over three minutes and was canceled. Cleanup attempts did not complete approval review, so whether that replacement device remains booted is unknown.
- The pass did not reach Jasonpedia Home and performed no app navigation, category taps, or product UI checks. Report and durable evidence summary: `docs/qa/2026-09-25-ios-wander-qa-pass.md` and `docs/qa/artifacts/2026-09-25-ios-wander-qa/runner-diagnostics.md`.

Next prerequisite for interactive QA is a CoreSimulator device/runtime that completes data migration and reaches a usable home screen. Once that works, retry runner health and continue the route map in `docs/qa/artifacts/2026-09-25-ios-wander-qa/route-map.md`; this run did not establish a working recovery path or complete an interactive smoke.

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
      recovery exists. Current outcome: unmodified 0.21.12 works on the recovered
      simulator with consistent elevated execution and session arguments.
- [x] Document the working recovery path in `docs/qa/README.md` if extra setup,
      longer timeouts, runner reset, or device cleanup is required.
- [x] Complete a short interactive smoke using `agent-device snapshot` plus at
      least one `press`/navigation step.
- [x] Capture or link evidence from the successful interactive smoke.

## Verification Guidance

- Run the documented `agent-device` workflow from `docs/qa/README.md` against
  the installed Debug app, pinning the iPhone 17 Pro UDID when multiple
  simulators are booted.
- Verify a usable simulator home screen before preparing the runner. The
  successful September 26 run used unmodified 0.21.12 and
  `prepare ios-runner --timeout 240000` on the recovered device.
- Confirm `open` establishes an active app session before attempting `snapshot -i`.
- Keep every command elevated and pass the same explicit state directory and
  session. The verified `open` command used `--timeout 120000`, supported by
  0.21.12. Earlier investigations above refer to older CLI timeout limits.
- Confirm `snapshot -i` returns accessibility refs without repeated timeouts.
- Press at least one visible control, re-snapshot, and capture a supporting
  screenshot under `docs/qa/artifacts/`.
