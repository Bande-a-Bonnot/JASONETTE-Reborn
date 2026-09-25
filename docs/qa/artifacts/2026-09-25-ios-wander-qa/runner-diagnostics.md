# Runner and simulator diagnostics — 2026-09-25

This note preserves the relevant outcomes from the temporary
`agent-device` 0.21.12 state and the primary agent's simulator commands. No
Jasonette category screen was reached.

## `agent-device` 0.21.12 runner preparation

Command:

```bash
/private/tmp/jasonette-agent-device-0.21.12/node_modules/.bin/agent-device prepare ios-runner \
  --platform ios \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --state-dir /private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc \
  --timeout 600000 \
  --debug
```

Observed in the saved runner log:

- `** TEST BUILD SUCCEEDED **` at approximately 14:42 UTC.
- `xcodebuild test-without-building` then started for
  `AgentDeviceRunnerUITests/RunnerTests/testCommand` on the planned simulator.
- Repeated warning: `IDERunDestination: Supported platforms for the buildables
  in the current scheme is empty`.
- The request log records repeated `ios_runner_connect` retry failures. The
  final runner command had `sessionReady:false` and returned `request canceled`.
- The CLI preparation timed out at its 630,000 ms daemon deadline; no healthy
  runner session was established.

Original temporary logs (may be removed with temp-state cleanup):

- `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc/daemon.log`
- `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc/sessions/cwd_3330371603901d14_ios/runner.log`
- `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc/sessions/cwd_3330371603901d14_ios/requests/320aa709a7ff9e97.ndjson`
- `/Users/thomas/.agent-device/logs/default/2026-09-25/2026-09-25T14-47-03-521Z-muh2ddkq-c76d27e9.ndjson`

## CoreSimulator runtime state

Original planned device:

```bash
xcrun simctl bootstatus 61EA0147-56E4-4399-8D51-F98A93B708A6 -b
xcrun simctl io 61EA0147-56E4-4399-8D51-F98A93B708A6 screenshot /private/tmp/jasonette-post-boot.png
```

Boot status: `Status=3, isTerminal=YES, Elapsed=00:51. Data Migration
Failed`. The screenshot succeeded and is copied into this artifact directory as
`simulator-data-migration-failed.png`; it shows a black screen with a centered
spinner.

Replacement iPhone 17 Pro device:

```bash
xcrun simctl bootstatus 9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB -b
xcrun simctl io 9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB screenshot /private/tmp/jasonette-fresh-boot.png
```

Boot status: `Status=3, isTerminal=YES, Elapsed=17:02. Data Migration
Failed`. The screenshot command remained hung for over three minutes and was
canceled; no image exists. Shutdown attempts failed to complete approval review,
so the replacement device's cleanup state is unknown.
