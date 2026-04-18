---
title: "$network.request silently drops non-object JSON responses"
date: 2026-04-17
module: ActionDispatcher
problem_type: runtime_error
component: service_object
severity: high
root_cause: wrong_api
resolution_type: code_fix
tags: [ios, swift, json, network, sdui, state-management]
symptoms:
  - "$response stays nil after a successful $network.request returning a JSON array"
  - "Demos that render array responses (CatchAll) display a blank screen"
  - "No error logged — data is dropped silently"
  - "Plaintext responses never populate $response"
related_components: [StateManager, TemplateEngine]
---

# $network.request Silently Drops Non-Object JSON Responses

## Problem

`ActionDispatcher.execute` decoded the response body of `$network.request` with a hard cast to `[String: Any]`. Any response whose top-level JSON value was not an object — arrays, scalars, `null`, or non-JSON plaintext — was silently discarded. `$response` was never written, subsequent template renders saw `nil`, and demos chained on array responses (very common for list endpoints feeding a `CatchAll` component) produced blank screens.

The narrow cast looked "safe" because `StateManager.set` takes `[String: Any]` — but that's the *outer* key/value bag, not the individual values. The value stored under `$response` can be `Any`.

## Symptoms

- `$network.request` → CatchAll demo in `Jasonpedia/` rendered an empty screen.
- No log line, no thrown error — execution continued as if the request had no body.
- Unit coverage only exercised object-shaped fixtures, so the gap never tripped a test.
- Plaintext error bodies (`"rate limited"`) were unreachable from templates.

## What Didn't Work

- **Blaming the renderer first.** The blank screen looked like a component-dispatch bug (`[Unknown: nil]` territory). Grepping the render path wasted time; the data never made it to the view model.
- **Relying on Swift error propagation.** `try?` swallowed the cast failure. There was no `catch` to inspect — the `if let` branch just didn't fire.
- **The original cast shape.** `as? [String: Any]` is the first thing Xcode suggests when you type-complete `JSONSerialization.jsonObject`. It encodes an implicit assumption about the API contract that the third-party server does not share.

## Solution

Decode with `.fragmentsAllowed`, store as `Any`, and fall back to a UTF-8 string when the body isn't valid JSON at all.

### Before

```swift
if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    stateManager.set(["$response": json])
}
```

### After

```swift
if let json = try? JSONSerialization.jsonObject(
    with: data,
    options: [.fragmentsAllowed]
) {
    stateManager.set(["$response": json])
} else if let text = String(data: data, encoding: .utf8) {
    stateManager.set(["$response": text])
}
```

Tests added in `ActionDispatcherTests.swift` using `StubURLProtocol` cover three shapes: dictionary body, array body, and plaintext body. Each asserts `$response` is populated with the expected value.

## Why This Works

- `.fragmentsAllowed` lifts the "top-level must be object or array" restriction, so JSON scalars (`"hello"`, `42`, `true`, `null`) decode cleanly.
- Storing under `$response` with `Any` type lets downstream template lookups (`$response[0].name`, `$response.items`, plain `$response`) resolve uniformly regardless of the underlying shape.
- The UTF-8 fallback means non-JSON endpoints (HTML error pages, plain text) are still observable to the template layer — useful for error-state UIs.

## Prevention

- **Default to the widest Foundation type when bridging external data.** Narrow only when you own the schema. HTTP bodies, deep links, pasteboard payloads, and IPC blobs all belong on the wide side.
- **Enumerate JSON top-level shapes in tests.** Object, array, scalar, null, and non-JSON. One test per shape. If your fixture library only has objects, your parser only handles objects.
- **Silent `if let` branches are a smell.** When a cast-shaped `if let` guards a critical side effect with no `else` and no log, assume it will fail in production and add a fallback or diagnostic.
- **When a demo renders blank, suspect the upstream parse before the renderer.** Put a breakpoint on the state write, not the view.

## Related

- `docs/solutions/runtime-errors/anycodable-nsjsonserialization-crash.md` — sister `JSONSerialization` pitfall; same "Foundation JSON API has sharp edges" theme, opposite direction (serialize vs. deserialize).
- `docs/solutions/build-errors/swiftui-modifier-gotchas.md` — parallel "silent nil override" trap where passing `nil` to `.foregroundColor` clobbers a parent value instead of inheriting. Both bugs are failure modes of *plausible-looking* code paths that produce no diagnostic.
- Commit `21847b7` on branch `fix/network-response-and-tab-items`.
