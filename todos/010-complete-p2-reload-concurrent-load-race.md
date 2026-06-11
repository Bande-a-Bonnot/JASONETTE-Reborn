---
status: complete
priority: p2
issue_id: "010"
tags: [code-review, correctness, concurrency, view-model]
dependencies: []
---

# `reload()` Creates Concurrent-Load Race Condition

## Problem Statement

`reload()` resets `loadState = .idle` then schedules a new `Task { await load() }`. Because `loadIfNeeded()` guards on `loadState == .idle`, resetting the state before the prior task completes creates a window where two concurrent `load()` tasks can both proceed. The last one to write `renderedRoot` wins non-deterministically. Additionally, `renderedRoot` is not cleared before reload, so stale content persists during the loading phase.

## Findings

**File:** `Rendering/JasonetteViewModel.swift`

```swift
func reload() {
    loadState = .idle           // resets guard used by loadIfNeeded
    Task { await load() }       // schedules new load — but old Task may still be running
}
```

If `reload()` is called while a `load()` task is awaiting a network response, both tasks run concurrently. Both will eventually call `render()` and write `renderedRoot`. The final state depends on which task completes last.

## Proposed Solutions

### Option A: Cancel the previous load task before scheduling a new one

```swift
private var loadTask: Task<Void, Never>?

func reload() {
    loadTask?.cancel()
    loadState = .loading
    loadTask = Task { await load() }
}
```
- Pros: No concurrent loads possible, `loadState` transitions correctly
- Cons: Requires URLSession to respect cancellation (it does)

### Option B: Guard with a `isLoading` flag distinct from `loadState`

Simpler but less rigorous than Option A.

## Recommended Action

Option A — explicit task cancellation is the correct Swift Concurrency pattern.

## Technical Details

- **Affected files:** `Rendering/JasonetteViewModel.swift` (reload and load methods)
- **Effort:** Small

## Acceptance Criteria

- [x] Calling `reload()` twice rapidly only results in one completed render
- [x] The stale task from a previous `reload()` does not write to `renderedRoot`
- [x] Test: `testReloadCancelsPreviousLoad`

## Work Log

- 2026-03-12: Identified by data-integrity-guardian agent during code review

## Completion Notes

Completed: 2026-06-11

`JasonetteViewModel` tracks the active load task, cancels it before `reload()`/`loadIfNeeded()` starts a replacement, and keeps `loadState` in `.loading` during reload. Added a URLProtocol-backed race regression proving a cancelled stale request does not render over the fresh reload result; repeated locally 10x without flake.

Verification: `swift test --filter ViewModelTests/testReloadCancelsPreviousLoad` (10 repeated runs).
