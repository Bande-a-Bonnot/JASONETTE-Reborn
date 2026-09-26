# Luna exploratory iOS QA — 2026-09-26

## Purpose

Act as a QA person using the installed Swift iOS app. Explore, follow promising
paths, try edge cases, and inspect the rendered UI visually. The route map is a
starting point, not a script or a coverage ceiling. Tests and direct-entry
fixture launches do not count as exploration through the app.

## Canonical environment

- Model: GPT-6 Luna; reuse the existing iOS QA agent.
- Simulator: `Jasonette-Wander-QA`, iPhone 17 Pro / iOS 26.2, UDID
  `9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB`.
- On September 26 the simulator returned a usable SpringBoard screenshot;
  yesterday's migration failure is historical, not today's health result.
- App: `com.bande-a-bonnot.jasonette`, Debug build from `2255ed4` at
  `/private/tmp/JasonetteIOSQA/Build/Products/Debug-iphonesimulator/Jasonette_iOS.app`.
  Confirm no iOS product changes since that build before using its results.
- CLI: `/private/tmp/jasonette-agent-device-0.21.12/node_modules/.bin/agent-device`.
- Session UUIDv7: `01a0dd3a-1ea6-74d5-a278-cce91b1103b6`.
- State directory: `/private/tmp/jasonette-qa-01a0dd3a-1ea6-74d5-a278-cce91b1103b6`.
- Pass both `--state-dir` and `--session` explicitly on every CLI command;
  the session name alone does not select the temporary daemon. Simulator
  commands require elevated access outside the filesystem sandbox.
- Starting document: normal `Jasonpedia/demo.json`, without entry overrides.
- Report: `docs/qa/2026-09-26-ios-luna-exploratory-qa.md`.
- Evidence: `docs/qa/artifacts/2026-09-26-ios-luna-exploratory-qa/`.

## Read first

Read this plan, `AGENTS.md`, `docs/qa/README.md`, the September 24 and 25 QA
reports, and `docs/qa/artifacts/2026-09-25-ios-wander-qa/route-map.md`.
Read the pinned CLI's `help workflow`, `help dogfood`, and relevant command
help. The primary agent prepares the device, then explicitly hands it over;
Luna owns all device interactions serially after that point.

## Exploration charter

1. Start at Home. Browse all five Tutorial categories and try multiple nested
   examples, going back through the actual app. Scroll past the first viewport.
   Sample Showcase links if available and record external/network failures.
2. Pursue interesting behavior beyond the suggested routes: navigation stacks,
   tabs, modals, repeated actions, leaving and re-entering screens, controls near
   the bottom of a scroll view, and restoration after dismissal. Keep a journey
   log so unexplored branches stay visible.
3. Exercise inputs with empty values, ordinary text, long text, emoji/non-ASCII,
   whitespace and multiple lines where supported. Inspect keyboard occlusion,
   focus, clearing, submission, dismissal, and whether displayed state updates.
4. Exercise native action demos and both ordinary and canceled flows where
   available: alerts, pickers, dates, toast/banner, media/share sheets, and
   permission handling. Use synthetic values and cancel external publishing or
   messaging actions. Distinguish a simulator limitation from an app defect.
5. Inspect screenshots while exploring. Look for clipping, truncation, overlap,
   contrast, missing content, alignment, safe-area errors, inaccessible controls,
   keyboard covering content, and strange scrolling. Sample dark appearance and
   rotation if the CLI supports them; restore the initial presentation afterward.
   Accessibility snapshots alone cannot establish visual correctness.
6. When something looks broken, reproduce it from a known screen. Capture the
   before/after state and minimal steps. Use source/fixture inspection afterward
   to distinguish renderer, fixture, network, and automation failures. Check
   existing todos before adding one; use UUIDv7 for any new todo IDs.

## Evidence and completion

Record actions actually performed, observed outcomes, screenshot paths, and
blocked/unexplored areas. Each finding needs severity, expected vs observed
behavior, reproduction steps, and evidence; label unconfirmed suspicions.
Include a useful breadth pass across the app and a second pass on risky or
surprising areas. Do not stop merely because a minimum route list was checked.
Avoid inventing a quota of bugs. Stop for a persistent tool failure after one
focused recovery, reporting the exact boundary of completed navigation.

No product fixes, broad test reruns, commits, or source changes during the QA
pass. The primary agent reviews findings, creates or reviews follow-up todos,
updates the handoff, and commits the evidence. Preserve pre-existing edits to
`AGENTS.md`, `CLAUDE.md`, and historical arbiter JSONs.
