---
status: pending
priority: p1
issue_id: "001"
tags: [code-review, security, state-management]
dependencies: []
---

# Network Response Overwrites Entire Render State Namespace

## Problem Statement

`ActionDispatcher.networkRequest()` merges the full JSON response body into `stateManager.local` with no key filtering. Since `stateManager.local` is the same dict that `TemplateEngine` uses as its render context, a compromised or malicious HTTP server can inject or overwrite any template context key (`$jason`, `$root`, `$index`, application keys) — enabling server-side template injection.

## Findings

**File:** `Sources/Jasonette/Core/ActionDispatcher.swift`, line ~213

```swift
if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    stateManager.set(json)  // merges ALL response keys into render context
}
```

Any key in the response dict overwrites local state. An attacker who controls the HTTP endpoint (or MITM on `http://`) can set `$jason` or any app-defined state key to arbitrary values, then trigger a re-render with injected content.

## Proposed Solutions

### Option A: Namespace under `$response` (recommended, minimal change)

Instead of `stateManager.set(json)`, use `stateManager.set(["$response": json])`. Template expressions then access `{{$response.field}}` — a server can only write to its own namespace.
- Pros: One-line fix, no API break, clear ownership
- Cons: Breaking change for any document that uses `$network.request` success and accesses response keys directly

### Option B: Declare allowed keys in action options

Add an `"output"` field to network action options listing which keys to extract from the response.
- Pros: Fine-grained control per action
- Cons: More complex, requires spec change

### Option C: Prefix all network-injected keys

Auto-prefix every response key with `_net_`. Template must reference `{{_net_field}}`.
- Pros: No spec change needed
- Cons: Ugly, non-standard

## Recommended Action

Option A — namespace under `$response`. Document the change in the Jasonette spec.

## Technical Details

- **Affected files:** `ActionDispatcher.swift` line ~213
- **Effort:** Small

## Acceptance Criteria

- [ ] Network response keys do not overwrite existing local state keys
- [ ] Template expressions can still access response data
- [ ] Test: server returning `{"$jason": "injected"}` does not overwrite the existing `$jason` context key
- [ ] Test: `{{$response.field}}` evaluates correctly after a `$network.request`

## Work Log

- 2026-03-12: Identified by security-sentinel agent during code review of PR fix/testflight-crashes-and-component-tests
