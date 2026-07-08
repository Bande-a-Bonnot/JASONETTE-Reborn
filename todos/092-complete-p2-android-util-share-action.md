---
id: "019f4311-3216-7f27-9cf2-3fbed3a7e0c5"
status: completed
priority: p2
issue_id: "092"
tags: [android, parity, actions, util, share]
dependencies: ["068", "076", "083"]
completed_at: "2026-07-08"
---

# Complete Android `$util.share` action baseline

## Outcome

Android now recognizes the legacy `$util.share` action in the built
`JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$util.share` through an injectable share seam,
  templates authored share items, and preserves success/error continuation
  behavior.
- Supported baseline share item forms include text, URL-as-text, `file_url`
  streams, and base64 `data` streams with optional `content_type`.
- `JasonetteViewModel` wires the dispatcher seam to a production
  `AndroidShareHandler`.
- `AndroidShareHandler` builds Android chooser intents, converts base64 data and
  `file://` streams to `content://` via `FileProvider`, accepts existing
  `content://` streams, and avoids exposing raw `file://` URIs.
- The manifest declares a FileProvider with authority `${applicationId}.fileprovider`
  and `@xml/jasonette_file_paths`; runtime code uses
  `${context.packageName}.fileprovider`, matching the installed application id
  including variant suffixes.

This is a baseline only. Legacy Android downloaded remote image URLs into share
streams; the current baseline shares remote non-stream URLs as text unless they
are already `content://` image URLs. Device/emulator chooser smoke remains a
future QA item.

## Verification

Added JVM dispatcher coverage in `ActionDispatcherTest` for:

- Templated text and URL share items invoking the share handler and running
  success chains.
- Image `data` items reaching the share seam with content type preserved.
- `file_url` items reaching the share seam and provider failures routing to an
  authored error branch.
- Missing items and missing production share support routing error branches.

A dedicated read-only reviewer subagent was run with `openai-codex/gpt-5.5` and
`xhigh` thinking as requested by the active parity goal. The first pass caught
critical issues around dropped base64 image data and raw `file://` exposure. The
follow-up pass reported no critical issues after adding FileProvider-backed
content-URI conversion, preserving data items, and confirming `networkClient`
remains the final trailing-lambda constructor parameter. It also noted the new
source/resource files were intentionally untracked before staging; they were
explicitly staged in the implementation commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `cd JASONETTE-Android/JasonetteApp && ./gradlew test --tests
com.jasonette.ActionDispatcherTest --no-daemon` fails before Gradle starts with
`Unable to locate a Java Runtime`.

GitHub Actions CI run `28967415682` passed for exact implementation head SHA
`eef468d0e5ab4b9fdfdb93a2b861c4d28965d707`; its Android job provisioned Java 17
and completed successfully.
