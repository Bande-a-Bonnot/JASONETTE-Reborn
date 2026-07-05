---
id: "019f1062-d5b8-7b01-8b6d-2ec4153d5884"
status: completed
priority: p2
issue_id: "075"
tags: [android, parity, includes, jasonpedia]
dependencies: ["068"]
completed_at: "2026-07-05"
---

# Complete Android legacy `+` include preprocessing

## Outcome

Android `DocumentLoader.load()` now preprocesses legacy Jasonette include
objects before decoding into `JasonDocument`.

Implemented support:

- Top-level remote `+` includes used by Jasonpedia webcontainer documents.
- Selector includes such as `items@...` and `item@...`.
- Local `$document...` references after top-level template expansion.
- Nested includes relative to the fetched include URL.
- HTTP(S)-only include fetching with unsafe schemes ignored for nested includes.
- Per-include-chain cycle protection and bounded remote include depth.
- Injectable JSON fetcher for deterministic JVM tests.

## Verification

Added `DocumentLoaderTest` coverage for:

- `Jasonpedia/webcontainer/pdf.json` resolving through
  `webcontainer/template.json` and `$document` fields.
- `Jasonpedia/webcontainer/feed/index.json` resolving selector includes for feed
  data, repeated item templates, and special feed items.
- Duplicate same-URL selector includes resolving independently.
- Local `$document` include cycles being depth/stack guarded.
- Unsafe top-level document URLs being rejected before fetch.
- Unsafe `file:` include references not being fetched.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: both `./gradlew test --tests com.jasonette.DocumentLoaderTest --no-daemon`
and `./gradlew test --no-daemon` fail before Gradle starts with `Unable to
locate a Java Runtime`. Verification should rely on the GitHub Actions Android
job, which provisions Java 17 and runs Gradle tests.
