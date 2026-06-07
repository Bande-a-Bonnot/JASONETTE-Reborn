---
id: "019ea2a2-9bbb-7836-961f-dc40dd6a4e0c"
status: complete
priority: p2
issue_id: "059"
tags: [ios, actions, vision, barcode, qrcode]
dependencies: ["058"]
---

# Implement native iOS `$vision.scan`

## Problem Statement

After `todos/058`, iOS vision paths were user-visible but still fallback-only.
The Jasonpedia vision fixture expects camera-backed vision lifecycle behavior:
`background: { "type": "camera" }` should make `$vision.ready` trigger the
named `qr` action, which dispatches `$vision.scan` and renders scanned content.

## Fix

- Added `VisionScanRequest` and an injectable `ActionDispatcher` vision scanner
  handler.
- `$vision.scan` now stores scanner payloads in local state and `$jason`, and
  passes them through success chains.
- Native iOS `JasonetteView` installs a scanner handler that presents an
  `AVCaptureSession`/`AVCaptureMetadataOutput` sheet for QR and common barcode
  formats.
- Camera permission denial, unavailable scanner hardware, cancellation, and
  handler failures route through normal action error handling.
- The Jasonpedia camera-background flow now fires `$vision.ready` after the
  rendered body declares a camera background, allowing the existing `qr` action
  chain to launch the scanner.
- If no native handler is installed, `$vision.scan` remains an explicit
  user-visible recognized fallback instead of a silent no-op.

## Acceptance Criteria

- [x] Direct `$vision.scan` can invoke a native scanner handler.
- [x] Scanner payloads set `$jason.content` and flow into success `$render` /
      alert chains.
- [x] Scanner failures can run authored `error` branches.
- [x] Jasonpedia `action/vision/index.json` fires `$vision.ready` and renders a
      scanner payload when a native handler is available.
- [x] No-handler paths still show a visible fallback alert.

## Verification

- `cd JASONETTE-iOS/JasonetteApp && swift test --filter ActionDispatcherTests/testVisionScan --filter ViewModelTests/testJasonpediaVision` — 6 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift test` — 558 tests, 0 failures.
- `cd JASONETTE-iOS/JasonetteApp && swift build` — passed.
- `cd JASONETTE-iOS/JasonetteApp && xcodebuild -project Jasonette.xcodeproj -scheme Jasonette-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build` — passed.

## Notes

Simulator visual QR scanning is not meaningful without a real camera feed. The
native iOS code path is covered by generic iOS Simulator build validation, while
scanner request/payload/error semantics are covered through injectable unit and
fixture tests.
