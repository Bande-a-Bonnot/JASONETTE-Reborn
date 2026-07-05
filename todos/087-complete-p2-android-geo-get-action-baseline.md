---
id: "019f3397-8d89-7df6-9a45-1733db412d24"
status: completed
priority: p2
issue_id: "087"
tags: [android, parity, actions, geo, location]
dependencies: ["068", "076", "083"]
completed_at: "2026-07-05"
---

# Complete Android `$geo.get` action baseline

## Outcome

Android now recognizes a baseline `$geo.get` action in the built
`JASONETTE-Android/JasonetteApp` renderer:

- `ActionDispatcher` dispatches `$geo.get` through an injectable geolocation
  provider seam for deterministic unit coverage.
- Successful coordinate reads store `coord`, legacy-compatible `value`, and a
  structured `$jason` payload for success-chain templating and `$render`.
- Provider failures route through the existing action error-chain behavior.
- `JasonetteViewModel` wires production dispatch to `AndroidGeolocationProvider`,
  so JSON actions are reachable from real rendered Jasonette documents.
- The Android manifest declares coarse/fine location permissions.

This is a baseline only. Production currently uses already-authorized
last-known Android locations and does not yet prompt for runtime permission or
actively request a fresh location update like legacy Android/iOS; those remain
future parity work.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- Successful `$geo.get` provider calls storing `coord`, `value`, and `$jason`.
- Coordinate payload flowing into `$render` success chains as `$jason`.
- Provider failure executing the authored `error` branch.

A read-only reviewer subagent checked the uncommitted implementation for compile
risk, production reachability, manifest/provider issues, and parity limits. It
found one critical constructor-order risk for existing trailing-lambda
`networkClient` call sites; the constructor parameter order was fixed before
commit and `rg "ActionDispatcher\\(" JASONETTE-Android/JasonetteApp/...` was
rechecked.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.ActionDispatcherTest --no-daemon` fail before Gradle starts
with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28737427201` passed for exact head SHA
`c8db2defe85022913b472731bc69e5149c80ae03`. Its Android job provisioned Java 17
and completed successfully.
