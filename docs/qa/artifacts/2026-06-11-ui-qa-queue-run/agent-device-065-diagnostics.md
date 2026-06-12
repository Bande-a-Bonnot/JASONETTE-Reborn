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
