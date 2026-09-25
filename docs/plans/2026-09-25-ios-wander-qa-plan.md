# iOS whole-app navigation QA — 2026-09-25

## Goal

Extend the 2026-09-24 Luna QA pass by navigating through the **installed iOS
app itself**. The earlier pass launched three isolated fixtures and did not
explore the home screen or browse between sections. This pass should describe
the actual journey through the app and find reproducible product issues without
assuming any quota of findings.

## Environment and shared values

- Read `AGENTS.md`, `docs/HANDOFF.md`, `docs/qa/README.md`, and
  `docs/qa/2026-09-24-ios-luna-qa-pass.md` first.
- Target: booted iPhone 17 Pro, iOS 26.2, UDID
  `61EA0147-56E4-4399-8D51-F98A93B708A6`.
- App bundle ID: `com.bande-a-bonnot.jasonette`.
- The installed Debug app was built on 2026-09-24 from `2255ed4` and is still
  installed. No iOS product source changed between that commit and this plan.
  Confirm the app remains installed before starting.
- Automation CLI: temporary `agent-device` 0.21.12 at
  `/private/tmp/jasonette-agent-device-0.21.12/node_modules/.bin/agent-device`.
- Automation state directory:
  `/private/tmp/jasonette-agent-device-qa-01a0d8fc-d8a1-7381-b687-04a62d5892cc`.
  Use UUIDv7 session `01a0d8fc-d8a1-7381-b687-04a62d5892cc`.
- The app's normal home document is `Jasonpedia/demo.json`. Its Tutorial section
  links to Core, View, Action, Template, and Web Container. The Showcase section
  links to external Instagram and Twitter examples.

## Method

1. Start the installed app at its normal home entry, without the Debug entry URL
   override. Use the automation CLI with the pinned UDID and state directory.
   The newer CLI accepts `--timeout`; run `prepare ios-runner` with a long startup
   budget before interactive commands. Keep one session and mutate the device
   serially. Read `agent-device help workflow` for exact command syntax.
2. Take an initial accessibility snapshot and screenshot. From the home screen,
   **tap** each Tutorial category: Core, View, Action, Template, and Web
   Container. Enter at least one representative nested example in each, then
   return through the app's own navigation. Scroll where needed. In Action,
   exercise a safe visible control; in View, inspect at least one component and
   one layout screen. Sample the Showcase links only if they load promptly.
3. Record a journey table with path, action, observed screen, result, and
   evidence. Distinguish navigation completed by taps from direct-entry
   recovery. Mark any skipped or blocked category explicitly. Capture targeted
   screenshots and snapshots; avoid a large gallery of redundant images.
4. For any apparent defect, reproduce it or corroborate it with focused
   source/test evidence. Separate fixture/network problems, harness failures,
   and product defects. Search existing todos before drafting a new one. Use
   UUIDv7 for any new todo ID.
5. Write a dated report under `docs/qa/` and evidence under a matching
   `docs/qa/artifacts/` directory. Include tool version, exact commands, app
   build provenance, and what interaction paths were actually covered.

## Recovery and limits

- Prior `agent-device` 0.17.4 attached but `snapshot -i` timed out after 90
  seconds. This pass uses 0.21.12 in a temporary directory. The first cold
  daemon startup raced its 15-second metadata timeout; retrying reached runner
  preparation. Read the current runner log if preparation or snapshot fails.
- If the updated runner still cannot return accessibility snapshots, try one
  bounded recovery supported by its CLI and document the exact result. Use
  direct-entry screenshots only as a clearly labeled fallback; do not call that
  an in-app navigation pass.
- Do not edit product code or commit. Preserve existing user changes to
  `AGENTS.md`, `CLAUDE.md`, and historical arbiter JSONs. The primary agent
  will review and commit QA evidence and verified todos.

## Done

The report demonstrates a route through all five Tutorial categories, with
representative nested screens and back navigation, or explicitly states which
categories could not be reached and why. It must not describe fixture launches
or unit tests as wandering through the app.
