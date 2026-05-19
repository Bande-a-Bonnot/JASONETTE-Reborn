# QA Notes

This directory stores exploratory QA passes and supporting evidence.

## iOS Simulator QA with `agent-device`

Use `agent-device` for agent-driven simulator QA. Raw `simctl` is excellent for
boot/install/launch/screenshot, but it does not provide high-level touch or
accessibility interaction. Posting CoreGraphics events to the Simulator window is
fragile and may fail under agent harness permissions. `agent-device` works by
bootstrapping an XCTest runner and exposing compact accessibility snapshots plus
interaction commands.

### Install / invoke

Prefer `npx` so the current CLI is used without adding a repo dependency:

```bash
npx --yes agent-device@latest --version
npx --yes agent-device@latest help workflow
```

The CLI help is authoritative; read `help workflow` before a QA pass.

### Basic loop

```bash
# Discover devices/apps
npx --yes agent-device@latest devices --platform ios
npx --yes agent-device@latest apps --platform ios

# Open the app and create a named session
npx --yes agent-device@latest open com.bande-a-bonnot.jasonette \
  --session jasonetteqa \
  --platform ios \
  --device "iPhone 17 Pro" \
  --relaunch

# Inspect visible UI and get refs
npx --yes agent-device@latest snapshot -i --session jasonetteqa --platform ios

# Interact using refs, then re-snapshot
npx --yes agent-device@latest press @e16 --session jasonetteqa --platform ios
npx --yes agent-device@latest snapshot -i --session jasonetteqa --platform ios

# Capture visual evidence when useful
npx --yes agent-device@latest screenshot docs/qa/artifacts/YYYY-MM-DD-ios-simulator/example.png \
  --session jasonetteqa \
  --platform ios

# End the session
npx --yes agent-device@latest close --session jasonetteqa --platform ios
```

### Operational notes from 2026-05-18/19

- The first `snapshot` can take a long time or time out while the XCTest runner
  starts. Retry once before assuming the app is inaccessible.
- Screenshots may show an iOS breadcrumb back to `AgentDeviceRunner...`; this is
  a QA harness artifact.
- Prefer accessibility refs from `snapshot -i`. If a control is collapsed or
  unlabeled, use `snapshot -i -c --json` to inspect rects and coordinate-fallback
  only with an explanation.
- Re-snapshot after every navigation, modal, alert, tab tap, or reload.
- Keep a live QA markdown note and capture screenshots only when they support a
  finding or important confirmation.

## QA report expectations

Each pass should record:

- date/time
- commit SHA
- macOS/Xcode versions
- simulator device/runtime
- build/install/launch commands
- entry URL/config
- areas tested and not tested
- severity-sorted findings with reproduction steps and evidence
- non-issues / confirmed working behavior
- recommended follow-up tickets

See `2026-05-18-ios-simulator-complete-qa.md` for the first agent-device-backed
pass.
