# iOS Whole-App Navigation QA — 2026-09-25

## Result

**Blocked before app launch.** No Tutorial or Showcase category was opened, and
no in-app navigation or product behavior was tested. The work completed was an
offline route map from `Jasonpedia/demo.json` and its linked index fixtures:
[route map](artifacts/2026-09-25-ios-wander-qa/route-map.md).

## Environment and provenance

- QA plan commit: `bc45a9f`
- App build under test per plan: Debug build from 2026-09-24 at `2255ed4`;
  bundle ID `com.bande-a-bonnot.jasonette`. Whether it remained installed on
  the failed simulator could not be confirmed.
- Target from plan: iPhone 17 Pro, iOS 26.2,
  `61EA0147-56E4-4399-8D51-F98A93B708A6`
- Replacement attempted by primary agent: iPhone 17 Pro, iOS 26.2,
  `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB`
- Xcode/macOS: Xcode 26.2, macOS 26.2
- Automation CLI: `agent-device` 0.21.12 at
  `/private/tmp/jasonette-agent-device-0.21.12/node_modules/.bin/agent-device`
- Automation state: `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc`
- Session UUIDv7: `01a0d8fc-d8a1-7381-b687-04a62d5892cc`

No app source changed between the installed app build and this pass. No app
launch, category tap, nested route, or back-navigation action occurred.

## Blockers and evidence

### 1. XCTest runner preparation timed out

The exact preparation command was:

```bash
/private/tmp/jasonette-agent-device-0.21.12/node_modules/.bin/agent-device prepare ios-runner \
  --platform ios \
  --udid 61EA0147-56E4-4399-8D51-F98A93B708A6 \
  --state-dir /private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc \
  --timeout 600000 \
  --debug
```

The XCTest runner test bundle built successfully. The subsequent
`test-without-building` phase did not establish the runner session. The saved
runner log records repeated `IDERunDestination: Supported platforms for the
buildables in the current scheme is empty` warnings. The saved request log
records repeated `ios_runner_connect` retries and a final `sessionReady:false`
/ `request canceled`. The prepare operation ended at the 630-second daemon
limit. This is automation/runtime evidence, not an app failure.

Durable excerpt and source-log locations:

- [runner preparation evidence](artifacts/2026-09-25-ios-wander-qa/runner-diagnostics.md)
- Original daemon log:
  `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc/daemon.log`
- Original runner log:
  `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc/sessions/cwd_3330371603901d14_ios/runner.log`
- Diagnostic log:
  `/Users/thomas/.agent-device/logs/default/2026-09-25/2026-09-25T14-47-03-521Z-muh2ddkq-c76d27e9.ndjson`

### 2. CoreSimulator could not finish device migration

The planned iPhone 17 Pro simulator reached terminal `Status=3 Data Migration
Failed` using:

```bash
xcrun simctl bootstatus 61EA0147-56E4-4399-8D51-F98A93B708A6 -b
```

Output: `[2026-09-25 14:49:38 +0000] Status=3, isTerminal=YES,
Elapsed=00:51. Data Migration Failed`.

The screenshot command succeeded:

```bash
xcrun simctl io 61EA0147-56E4-4399-8D51-F98A93B708A6 screenshot /private/tmp/jasonette-post-boot.png
```

Its captured screen remained black with a centered activity spinner:
[original simulator boot screen](artifacts/2026-09-25-ios-wander-qa/simulator-data-migration-failed.png).

A newly created iPhone 17 Pro simulator with UDID
`9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB` also ended in `Status=3 Data Migration
Failed` after 17 minutes 2 seconds:

```bash
xcrun simctl bootstatus 9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB -b
```

Output: `[2026-09-25 15:26:51 +0000] Status=3, isTerminal=YES,
Elapsed=17:02. Data Migration Failed`. Capturing the second device's screen
with
`xcrun simctl io 9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB screenshot /private/tmp/jasonette-fresh-boot.png`
hung for over three minutes and was canceled; no screenshot was produced.
Shutdown cleanup of the temporary device was not verified because the approval
review timed out on both cleanup attempts. Do not assume that device has been
removed or shut down.

## Journey coverage

| Planned route | Result | Reason |
| --- | --- | --- |
| Normal Jasonpedia home (`Jasonpedia/demo.json`) | **BLOCKED** | Simulator migration failed before app launch |
| Tutorial → Core → nested example → back | **NOT TESTED** | Home screen unavailable |
| Tutorial → View → component and layout → back | **NOT TESTED** | Home screen unavailable |
| Tutorial → Action → safe visible action → back | **NOT TESTED** | Home screen unavailable |
| Tutorial → Template → nested example → back | **NOT TESTED** | Home screen unavailable |
| Tutorial → Web Container → nested example → back | **NOT TESTED** | Home screen unavailable |
| Showcase links | **NOT TESTED** | Skipped because the Tutorial entry point was unavailable |

These are not completed navigation results. The offline route map only records
the authored links and a proposed tap order; it does not substitute for
observing those routes in the installed app.

## Findings and next action

No product defect was observed because the app did not reach a screen. No new
product todo was created. The existing agent-device investigation is tracked in
[`todos/065-p3-stabilize-agent-device-ios-snapshot-qa.md`](../../todos/065-p3-stabilize-agent-device-ios-snapshot-qa.md), updated with this
runner and CoreSimulator evidence.

Next, restore or create an iOS 26.2 simulator that completes CoreSimulator
migration and reaches Home. Confirm that state with `simctl bootstatus` and a
usable boot screenshot, then prepare the runner and execute the route map with
in-app taps and back navigation. Keep the temporary simulator's cleanup status
unverified until a shutdown succeeds.
