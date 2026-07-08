---
id: "019f4358-ab91-7ea3-a9ae-943074030375"
status: completed
priority: p2
issue_id: "095"
tags: [android, parity, actions, network, upload, s3]
dependencies: ["068", "076", "083"]
completed_at: "2026-07-08"
---

# Complete Android `$network.upload` action baseline

## Outcome

Android now recognizes the legacy signed-S3 `$network.upload` action in the
built `JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$network.upload` instead of letting it fall
  through as an unknown action that would incorrectly run success continuations.
- Upload options are templated before execution and follow the legacy/docs
  contract: `bucket`, `data`, optional `path`, `sign_url`, optional `type: "s3"`,
  and optional `content_type`.
- The generated object path uses a UUIDv7 filename. It follows legacy path shape:
  `path/uuid` when `path` is authored, or `/uuid` when no path is authored.
- The signing request calls `sign_url` with `bucket`, generated `path`, and
  `content-type` query parameters.
- Signer responses must contain `{ "$jason": "https://...signed-url..." }`.
- The upload step PUTs base64-decoded `data` to the signed URL with the selected
  content type.
- Successful uploads store `{ filename, file_name }` in top-level local state and
  `$jason` for success chains.
- Missing required options, invalid base64, missing/invalid signer payloads,
  unsafe URLs, signer failures, and PUT failures route authored `error`
  continuations.
- Production network I/O now runs on `Dispatchers.IO` for the default
  `HttpURLConnection` paths.
- `networkClient` remains the final constructor parameter, preserving existing
  trailing-lambda `ActionDispatcher(sm) { ... }` call sites.

This is a baseline focused on the documented/legacy signed-S3 flow. Richer
multipart/form-data upload semantics mentioned in the current spec remain future
work.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- Successful sign → PUT flow, UUIDv7 filename shape, exact returned filename
  payload, and success-chain access via `$jason.filename`.
- Exact signer query key matching the returned/generated filename.
- Base64 data URI and wrapped/newline base64 decoding compatibility.
- Templated `path`/`data` options and fallback content type from
  `$jason.content_type` when `options.content_type` is absent.
- Invalid base64 routing an authored error branch.
- Missing `$jason` in signer response preventing upload and routing an authored
  error branch.
- PUT/upload failure routing an authored error branch.

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout compared the legacy
Java implementation, official docs, and current Kotlin renderer before
implementation. A dedicated `openai-codex/gpt-5.5` / `xhigh` reviewer found no
critical issues; warnings about strict base64 decoding and signer filename
assertion coverage were addressed before commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: targeted `./gradlew test --tests com.jasonette.ActionDispatcherTest
--no-daemon` fails before Gradle starts with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28972136551` passed for exact implementation head SHA
`527b51ae17fb4500bc42066173e7b4ddaf7d0019`; its Android job provisioned Java 17,
built the app, and completed the test suite successfully.
