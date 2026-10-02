# iOS todos 106–108 verification

Status: in progress. Date: 2026-10-02.

## Workflow and regression evidence

The canonical workflow is
[`remaining backlog workflows`](../plans/2026-10-02-ios-remaining-backlog-workflows.md).
Each task has a fresh GPT-6.1 Sol xhigh source reviewer. Root runs all tests,
builds and simulator commands serially with two build jobs.

Before implementation, elevated `swift test --jobs 2 --quiet` passed 622/622.
Scoped red runs then compiled successfully:

- `swift test --jobs 2 --filter 'ActionDispatcherTests/testMediaCancellation|HTMLBodyBackgroundTests'`:
  17 tests, 22 failures, including three background decode errors. Cancellation
  ran 11 tests with 17 assertion failures; HTML body background ran six tests
  with five failures. Log: `/private/tmp/jasonette-ios-2026-10-02-red-106-108.log`.
- `swift test --jobs 2 --filter 'RendererAppearanceTests|ColorParsingTests'`:
  39 tests, 36 failing assertions in 14 appearance tests; all 25 color parsing
  tests passed. Log: `/private/tmp/jasonette-ios-2026-10-02-red-107.log`.

Green results and actual iOS acceptance have not yet been recorded.

## Independent source review

- 108: fresh GPT-6.1 Sol xhigh reviewer `ios108_review_sol61` reported no
  findings in ActionDispatcher.swift and ActionDispatcherTests.swift. The review
  checked authored error continuation payload/ordering, enclosing success
  cancellation through named wrappers, utility selection and timer boundaries,
  existing media storage, and ordinary error recovery. It ran no commands that
  test the app; green and native acceptance remain root-owned.
- 106: fresh GPT-6.1 Sol xhigh reviewer `ios106_review_sol61` found an
  acceptance blocker: the destination's displayed navigation title still uses
  the included template's head title, while the authored `SVG Clock` title is
  in the rendered body header. No other findings. The worker is repairing title
  resolution and adding direct pipeline assertions; focused re-review pending.
- 107: fresh GPT-6.1 Sol xhigh reviewer `ios107_review_sol61` found two P2
  defects: an inner default foreground overriding selected/unselected footer
  tab tint, and appearance defaults derived from a discarded CSS color when
  a canonical HTML background is rendered instead. Worker repairs and focused
  re-review are pending. No further findings in the scoped review.

The first integrated focused green attempt compiled product source but failed
to compile a newly added HTML test: its single-`#` raw string delimiter collided
with the `#123456` color value (`HTMLBodyBackgroundTests.swift:198`). This is a
test syntax error, not a behavioral red result. The worker is correcting it.
Log: `/private/tmp/jasonette-ios-2026-10-02-green-focused.log`.

## QA environment

Retained iPhone 17 Pro / iOS 26.2 simulator `Jasonette-Wander-QA`, UDID
`9DC9D1D3-EB82-4D9F-A125-9E1219A3D8CB`. Boot succeeded. September's temporary
agent-device package had been partially cleaned up; unmodified pinned 0.21.12
was restored using `npm install --prefix /private/tmp/jasonette-device-20261002
--no-audit --no-fund agent-device@0.21.12`.

Canonical CLI: `/private/tmp/jasonette-device-20261002/node_modules/.bin/agent-device`.
Canonical state directory: `/private/tmp/jasonette-device-state-20261002`.
Canonical UUIDv7 session: `01a0fddd-2485-7115-aabe-f3a66cfa22ce`.
Every agent-device and simctl command uses elevated host access.

The initial `prepare ios-runner --timeout 240000` failed while setting up the
device with `xcrun timed out after 15000ms`, before interaction. Diagnostic:
`sessions/01a0fddd-2485-7115-aabe-f3a66cfa22ce/requests/3216f92322ee23d5.ndjson`
under the canonical state directory. Root will retry after the scoped test run
to avoid concurrent host build work.

The next attempt exhausted the 240-second Apple runner startup budget, after
cache warming and device readiness completed. Root started a cached retry with
`--timeout 600000`; preparation is still in progress. Fixture serving is scoped
to `docs/qa/fixtures` on `127.0.0.1:8767`, so direct URLs use
`http://127.0.0.1:8767/ios-html-106/index.json`,
`http://127.0.0.1:8767/ios-appearance-107/index.json`, and
`http://127.0.0.1:8767/ios-cancellation-108/index.json`.

## Acceptance checklist

- [ ] 106: normal Home → Tutorial → Web Container, SVG Clock and second HTML
  destination, back navigation; clock visible and animated; plain inline and
  URL HTML internal DOM interaction retained.
- [ ] 107: heading, placeholder and entered text readable in light and dark;
  focus and secure/textarea behavior; explicit colors retained; restore light.
- [ ] 108: normal native picker cancel returns quietly twice; authored error
  cancel runs its alert exactly once; no success/share continuation.
- [ ] Fresh source reviews, full Swift suite and generated iOS build pass.
- [ ] Record source commits and screenshots, close session/server, stop simulator.
