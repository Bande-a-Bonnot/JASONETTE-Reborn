---
id: "019f4385-9039-7607-bce3-78427011fdfa"
status: completed
priority: p2
issue_id: "096"
tags: [android, parity, actions, vision, scanner]
dependencies: ["068", "079", "083"]
completed_at: "2026-07-08"
---

# Complete Android `$vision.scan` action baseline

## Outcome

Android now recognizes `$vision.scan` in the built `JASONETTE-Android/JasonetteApp`
renderer:

- `ActionDispatcher` dispatches `$vision.scan` through an injectable scanner seam
  instead of treating it as an unknown action that would incorrectly continue as
  success.
- Scan options are templated before execution; `options.type: "qr"` or
  `"qrcode"` narrows production scanning to QR codes.
- Successful scans store at least `content` plus barcode type metadata in
  top-level local state and `$jason`.
- Successful scans also dispatch a named `$vision.onscan` action when authored,
  preserving the legacy Android event flow used by the Jasonpedia vision fixture.
- The original `$vision.scan.success` chain still runs after the `$vision.onscan`
  hook so direct/iOS-style awaited scanner flows also work.
- Missing/unavailable/cancelled scanner paths route authored `error` chains.
- `JasonetteViewModel` exposes a native vision request and fires `$vision.ready`
  after rendering camera-background documents so legacy camera-background flows
  can start their scan chain.
- Camera backgrounds are recognized in string and object forms from both
  `body.background` and `body.style.background`.
- `JasonetteScreen` launches Google Play Services Code Scanner through a small
  `AndroidVisionScanner` adapter and uses request-scoped completion/cancellation
  so stale scanner callbacks cannot complete a newer native request.
- `networkClient` remains the final `ActionDispatcher` constructor parameter,
  preserving existing trailing-lambda `ActionDispatcher(sm) { ... }` call sites.

This is a baseline scanner implementation. It uses the Play Services Code
Scanner UI (`com.google.android.gms:play-services-code-scanner`) rather than an
in-app CameraX/ML Kit camera preview. That scanner API owns the camera UI and
permission flow, so this slice intentionally does not add an app-level `CAMERA`
manifest permission or runtime permission plumbing.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- `$vision.scan` passing a templated type request to the scanner seam, storing
  scan payload fields in local state and `$jason`, and letting success chains
  read `{{$jason.content}}`.
- Dispatching legacy named `$vision.onscan` with the scan payload.
- Running both `$vision.onscan` and the original `$vision.scan.success` chain.
- Unavailable and cancelled scanner paths routing authored `error` branches.

Added `AndroidFooterRenderingTest` coverage for camera-background helper shapes:

- `body.background: "camera"`
- `body.background: {"type":"camera"}`
- `body.style.background: "camera"`
- `body.style.background: {"type":"camera"}`

A dedicated read-only `openai-codex/gpt-5.5` / `xhigh` scout compared current
Android, legacy Android `JasonVisionAction`/`JasonVisionService`, iOS scanner
semantics, and Jasonpedia. Dedicated `openai-codex/gpt-5.5` / `xhigh` reviewer
passes caught and helped address legacy `$vision.onscan`, camera-background
shape, success-chain, stale callback, and untracked-file risks before commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: targeted `./gradlew test --tests com.jasonette.ActionDispatcherTest
--tests com.jasonette.AndroidFooterRenderingTest --no-daemon` fails before
Gradle starts with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28975042853` passed for exact implementation head SHA
`7b792b673a8d860e47260607b5910ba9fe785903`; its Android job provisioned Java 17,
built the app, and completed the test suite successfully.
