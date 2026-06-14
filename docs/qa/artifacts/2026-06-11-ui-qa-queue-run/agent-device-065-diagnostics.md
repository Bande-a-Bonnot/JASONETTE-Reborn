# agent-device 065 Diagnostics — 2026-06-12

## Summary

`agent-device` 0.17.2 iOS automation fails before interactive QA can start. Raw
`simctl` app launches work, and `prepare ios-runner` can succeed when given a
longer timeout, but `agent-device open` still has a hard 90s daemon request
timeout and fails before establishing an active app session.

This reproduces on both the primary iPhone 17 Pro simulator and a second booted
iPhone SE simulator after installing the Jasonette app there, so it is not an app
install/launch failure and not obviously tied to one simulator device. It remains
an `agent-device`/Xcode runner timeout or lease/handshake issue.

## Devices

- iPhone 17 Pro / iOS 26.2:
  `61EA0147-56E4-4399-8D51-F98A93B708A6`
- SeeYou iPhone SE 3rd Gen 26.2 QA:
  `A9CEAA75-883C-48DB-BDDD-E6A360DE8136`

## Raw app launch checks

These succeeded:

```bash
xcrun simctl launch --terminate-running-process \
  61EA0147-56E4-4399-8D51-F98A93B708A6 \
  com.bande-a-bonnot.jasonette

xcrun simctl install \
  A9CEAA75-883C-48DB-BDDD-E6A360DE8136 \
  JASONETTE-iOS/JasonetteApp/DerivedData/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app

xcrun simctl launch --terminate-running-process \
  A9CEAA75-883C-48DB-BDDD-E6A360DE8136 \
  com.bande-a-bonnot.jasonette
```

## agent-device attempts

### Default state dir, iPhone 17 Pro

Command:

```bash
npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session jasonette065 \
  --platform ios \
  --device "iPhone 17 Pro" \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --relaunch \
  --debug
```

Logs:

- Request: `/Users/thomas/.agent-device/sessions/jasonette065/requests/25d0ace11d67cbae.ndjson`
- Runner: `/Users/thomas/.agent-device/sessions/jasonette065/runner.log`

Key lines:

```text
runner_xctestrun_cache action=reuse reason=reuse_ready
phase=ios_runner_connect event=exhausted
error="Runner did not accept connection"
reason="prepare_cached_runner_health_failed"
runner_xctestrun_cache action=clean reason="Runner did not accept connection"
runner_xctestrun_cache action=rebuild reason=missing_xctestrun
ios_runner_session_prewarm_failed error="xcodebuild build-for-testing failed"
```

### Fresh state dir, iPhone 17 Pro

Command used `--state-dir /tmp/agent-device-jasonette065-state`.

Logs:

- Request: `/tmp/agent-device-jasonette065-state/sessions/jasonette065/requests/b379716b459b925d.ndjson`
- Runner: `/tmp/agent-device-jasonette065-state/sessions/jasonette065/runner.log`

Key lines:

```text
runner_xctestrun_cache action=build reason=built_new
** TEST BUILD SUCCEEDED **
ios_runner_connect attempt_failed
error="request canceled"
** BUILD INTERRUPTED **
```

Interpretation: the fresh runner build can succeed, but the fixed 90s daemon
request timeout interrupts the subsequent `test-without-building` runner
handshake.

### Fresh state dir + `--no-device-hub`, iPhone 17 Pro

Command used `--state-dir /tmp/agent-device-jasonette065-nodevicehub` and
`--no-device-hub`.

Logs:

- Request: `/tmp/agent-device-jasonette065-nodevicehub/sessions/jasonette065c/requests/9198f8c530afb785.ndjson`
- Runner: `/tmp/agent-device-jasonette065-nodevicehub/sessions/jasonette065c/runner.log`

Key lines:

```text
runner_xctestrun_cache action=reuse reason=reuse_ready
phase=ios_runner_connect event=exhausted
error="Runner did not accept connection"
reason="prepare_cached_runner_health_failed"
runner_xctestrun_cache action=clean reason="Runner did not accept connection"
runner_xctestrun_cache action=rebuild reason=missing_xctestrun
** BUILD INTERRUPTED **
```

Interpretation: `--no-device-hub` does not clear the runner connection problem.

### Extended prepare timeout, iPhone 17 Pro

Command:

```bash
npx --yes agent-device@latest prepare ios-runner \
  --platform ios \
  --device "iPhone 17 Pro" \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --state-dir /tmp/agent-device-jasonette065-prepare \
  --session jasonette065prep \
  --timeout 360000 \
  --debug
```

Result:

```text
Prepared Apple runner: iPhone 17 Pro
```

The command completed in about 166s. This shows the runner can build/start and
pass prepare health-checks when the prepare command gets enough wall-clock
budget.

However, a subsequent `agent-device open` in the same state dir/session still
hit the command's fixed 90s daemon request timeout:

- Request: `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep/requests/03e2bf102c409e08.ndjson`

A following `snapshot -i` failed with `SESSION_NOT_FOUND` because `open` had not
established an active app session:

- Request: `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep/requests/85593851521adcc2.ndjson`

After `disconnect` reported no remote connection, another `open` attempt also
hit the 90s timeout:

- Request: `/tmp/agent-device-jasonette065-prepare/sessions/jasonette065prep2/requests/baf8cacad263a6de.ndjson`

`agent-device open --help` in 0.17.2 does not expose a command-level `--timeout`
flag, unlike `prepare ios-runner`. The broader `prepare ios-runner --help` text
mentions `clean:daemon`, but the installed 0.17.2 command list does not include a
`clean:daemon` command. The available cleanup-adjacent command is `disconnect`
(`disconnect [--shutdown]`), documented as disconnecting remote daemon state,
stopping an owned Metro companion, and releasing leases. Running `disconnect`
against the prepared local state reported `No remote connection`, and a
subsequent `open` still hit the same 90s daemon request timeout.

### Fresh state dir, second simulator (iPhone SE)

Command used `--state-dir /tmp/agent-device-jasonette065-se` and UDID
`A9CEAA75-883C-48DB-BDDD-E6A360DE8136` after installing Jasonette.

Logs:

- Request: `/tmp/agent-device-jasonette065-se/sessions/jasonette065se/requests/ae36b7d31b82479a.ndjson`
- Runner: `/tmp/agent-device-jasonette065-se/sessions/jasonette065se/runner.log`

Key lines:

```text
runner_xctestrun_cache action=rebuild reason=missing_xctestrun
[runner build still in progress when daemon_request_timeout fired]
```

Interpretation: the same fixed 90s daemon request timeout reproduces on a second
simulator. This supports treating the issue as an `agent-device`/Xcode runner
startup-budget or lease/handshake problem, not a Jasonette app failure.

## 2026-06-13 Follow-up: 0.17.3 and clean runner cache

`agent-device@latest` resolved to 0.17.3. A fresh recovery attempt pinned the
same iPhone 17 Pro UDID and first reduced environmental noise:

- Shut down the second booted SE simulator.
- Killed visible `agent-device`, `xcodebuild`, and `AgentDeviceRunner` processes.
- Moved aside `~/.agent-device/ios-runner/derived` instead of relying on the
  earlier foreground `rm -rf`, which had hung before completing.
- Recreated an empty `~/.agent-device/ios-runner/derived` directory.

Command:

```bash
npx --yes agent-device@latest prepare ios-runner \
  --platform ios \
  --device "iPhone 17 Pro" \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --state-dir /tmp/agent-device-jasonette065-clean-v0173 \
  --session jasonette065clean \
  --timeout 600000 \
  --debug
```

Logs:

- Request: `/tmp/agent-device-jasonette065-clean-v0173/sessions/jasonette065clean/requests/43ebf35046665cfe.ndjson`
- Runner: `/tmp/agent-device-jasonette065-clean-v0173/sessions/jasonette065clean/runner.log`

Key lines:

```text
runner_xctestrun_cache action=build reason=built_new
** TEST BUILD SUCCEEDED **
ios_runner_command_send error="Runner did not accept connection"
ios_runner_session_invalidated reason="prepare_runner_health_failed"
reason="IOS_RUNNER_CONNECT_TIMEOUT"
```

One retry also logged stale runner-bundle cleanup trouble:

```text
ios_runner_startup_cleanup_stale_bundle_failed
bundleId="com.callstack.agentdevice.runner.uitests.xctrunner"
timeoutMs=10000
error="xcrun timed out after 10000ms"
```

Interpretation: after the runner app builds successfully, the
`test-without-building` runner never accepts the HTTP command endpoint within the
90s connect window. The saved `runner.log` shows the `xcodebuild
test-without-building -only-testing AgentDeviceRunnerUITests/RunnerTests/testCommand`
invocation, but no `Test Suite` / `Test Case` start lines and no HTTP/listen/server
port-bind output before `** BUILD INTERRUPTED **`. This suggests XCTest never
reaches `RunnerTests.testCommand` (or reaches it before any visible runner logging),
so the failure remains below Jasonette and at the agent-device runner/XCTest
startup layer.

A version-pin fallback was also attempted:

```bash
npx --yes agent-device@0.14.9 open com.bande-a-bonnot.jasonette \
  --session jasonette065v0149open \
  --platform ios \
  --device "iPhone 17 Pro" \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --state-dir /tmp/agent-device-jasonette065-v0149-open \
  --relaunch \
  --debug
```

0.14.9 predates `prepare ios-runner`, and `open` still hit the fixed 90s daemon
request timeout:

- Diagnostic: `/Users/thomas/.agent-device/logs/jasonette065v0149open/2026-06-13/2026-06-13T15-27-11-978Z-mqcibzy0-81a8d5b8.ndjson`
- Daemon log: `/tmp/agent-device-jasonette065-v0149-open/daemon.log`

Sanity checks after the failed runner attempts showed basic CoreSimulator and
Jasonette launch paths were still alive:

```text
xcrun simctl list devices booted                         # ~2s
xcrun simctl get_app_container ... com.bande-a-bonnot... # ~2s
xcrun simctl launch --terminate-running-process ...      # ~12s, returned pid
```

Moved-aside runner caches were then removed. The active
`~/.agent-device/ios-runner/derived` directory was empty, and
`agent-device@latest session list --state-dir /tmp/agent-device-jasonette065-clean-v0173`
returned `"sessions": []`.

Current conclusion as of 2026-06-13: no reliable local recovery path has been
identified. Treat interactive `agent-device` iOS QA as blocked by the tool/XCTest
runner handshake on this host until the runner can accept commands; continue
using pinned raw `simctl` launch/screenshot for non-interactive visual evidence.

## 2026-06-14 Follow-up: temporary 0.17.4 patch shows runner can bind, but `open` still times out

`agent-device@latest` advanced to 0.17.4 in the same npx cache path:

```text
/Users/thomas/.npm/_npx/d03929938e601151/node_modules/agent-device
```

Important cache/version caution: future retries must first confirm the exact
`agent-device` package path and version being executed. `npx --yes
agent-device@latest` can reuse or replace `_npx` cache directories, and a result
from one cached package may not describe another.

A temporary local patch was applied only to that cached package to test whether
runner port propagation was involved. The patch added `AGENT_DEVICE_RUNNER_PORT`
to generated `.xctestrun` `CommandLineArguments`; it was then restored. Restored
`dist/src/2415.js` SHA-256:

```text
5dcb3e8f11788ea76860cad090ed63ebd064d9a26a8a1ce20bdb0f1cffc05371
```

With the temporary patch and an extended timeout, `prepare ios-runner` succeeded. This was not a verified unpatched 0.17.4 recovery run:

```bash
node /Users/thomas/.npm/_npx/d03929938e601151/node_modules/agent-device/bin/agent-device.mjs prepare ios-runner \
  --platform ios \
  --device "iPhone 17 Pro" \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --state-dir /tmp/agent-device-jasonette065-0174-argpatch \
  --session jasonette0650174argprep \
  --timeout 600000 \
  --debug
```

Evidence:

- Request: `/tmp/agent-device-jasonette065-0174-argpatch/sessions/jasonette0650174argprep/requests/d40c09c68bf290c9.ndjson`
- Runner: `/tmp/agent-device-jasonette065-0174-argpatch/sessions/jasonette0650174argprep/runner.log`

Key runner lines:

```text
Test Suite 'RunnerTests' started
AGENT_DEVICE_RUNNER_DESIRED_PORT=52909
AGENT_DEVICE_RUNNER_LISTENER_READY
AGENT_DEVICE_RUNNER_PORT=52909
AGENT_DEVICE_RUNNER_COMMAND_ACCEPTED command=shutdown
Test Case '-[AgentDeviceRunnerUITests.RunnerTests testCommand]' passed
```

This proves XCTest can reach `RunnerTests.testCommand`, resolve the desired port,
bind the listener, and accept at least a shutdown command when the command has
enough wall-clock budget.

A following `open` in the same state/session, still during the temporary patched experiment, failed:

- Request: `/tmp/agent-device-jasonette065-0174-argpatch/sessions/jasonette0650174argprep/requests/2dd0483cfe49bf71.ndjson`

Key request-log sequence:

```text
runner_xctestrun_cache action=reuse reason=reuse_ready
ios_runner_session_startup_timings ... command="uptime" ... ready=false
ios_runner_session_invalidated reason="prepare_cached_runner_health_failed"
runner_xctestrun_cache action=clean reason="Runner did not accept connection"
runner_xctestrun_cache action=rebuild reason="missing_xctestrun"
ios_runner_session_prewarm_failed error="xcodebuild build-for-testing failed"
daemon_request_timeout timeoutMs=90000 command=open
```

Interpretation: the temporary patch experiment showed `prepare` can warm and
then shut down its runner; a later `open` still needs a fresh runner health
check. `open` exposes no timeout flag, so its built-in runner health/startup
budget plus the fixed 90s daemon request timeout can still expire before an app
session is established. The blocker is therefore not just missing port
propagation; it is the combination of `prepare` not leaving a command-ready app
session for `open`, and `open` lacking an extended startup budget on this host.
After this experiment, the cached 0.17.4 package was restored; no unpatched
0.17.4 `open`/`snapshot` recovery was verified after restore.
