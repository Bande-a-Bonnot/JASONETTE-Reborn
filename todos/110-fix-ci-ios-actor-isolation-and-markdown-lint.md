---
id: "01a10338-51c7-78ac-8646-1d30f3f5219a"
status: open
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
