---
id: "01a10338-51c7-78ac-8646-1d30f3f5219a"
status: complete
priority: p2
issue_id: "110"
tags: [ios, ci, swift, concurrency, documentation]
dependencies: []
---

# Restore iOS package build and Markdown lint in GitHub Actions

The October3 push exposed compiler errors on the macos14 runner in HTML WebKit
helpers and horizontal layout child creation, despite local Xcode26.2 success.
The workflow report also contains one extra blank line rejected by MD012.

## Definition of Done

- Explicit, correct actor isolation compiles on the existing CI runner and the
  local toolchain without suppressing checks or skipping build/tests.
- HTML interaction/sizing and horizontal layout behavior retain existing tests.
- Markdown lint passes with the existing configuration.
- Independent GPT-6.1 Sol xhigh review has no unresolved findings.
- Exact implementation-head CI proves iOS Build/Test and lint all passed.
- Fixes and evidence are committed/pushed; handoff records current CI health.

[Canonical workflow](../docs/plans/2026-10-03-ci-repair-workflow.md) assigns
Sol high planning/implementation, xhigh review, and serial root-owned gates.

## Resolution — 2026-10-03

Explicit UI actor isolation and pure nonisolated height helpers restore the
existing macos14 CI build; one extra Markdown blank line was removed. Repair
source `0b4800784ba253dd8dd532c06b75e40e97495cf3` is pushed.
[Exact-head CI](https://github.com/Bande-a-Bonnot/JASONETTE-Reborn/actions/runs/37148371099)
passed iOS Build, Test (679 tests, zero failures) and Markdown lint on Xcode 15.4
/ Swift 5.10. Local build, 28 focused tests, 679 full tests and lint passed;
independent Sol xhigh review found no concrete issues.
[Verification record](../docs/qa/2026-10-03-ci-repair-verification.md).
