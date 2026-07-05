---
id: "019f3054-63ee-7beb-8282-1391dce04b2b"
status: completed
priority: p2
issue_id: "082"
tags: [android, parity, rendering, header, background]
dependencies: ["068", "080"]
completed_at: "2026-07-05"
---

# Complete Android body header/background color baseline

## Outcome

Android now handles a small but visible body-level rendering parity slice:

- `JasonBody` decodes `style` as raw JSON, allowing rendered templates to
  preserve legacy `body.style.background` without rejecting existing object-valued
  background payloads.
- `JasonetteScreen` uses `body.header.title` for the top app bar when present,
  falling back to `head.title`.
- `body.header.menu` renders in the top app bar actions area and reuses the
  normal component href/action dispatch paths.
- Body background color strings from `body.style.background` or string
  `body.background` are applied behind the document list through the shared CSS
  color parser.

This is a color/header baseline only. Richer legacy Android header/search/menu
semantics and HTML/camera/image background objects remain future work.

## Verification

Added JVM coverage for pure rendering helpers:

- `body.header.title` overriding `head.title`.
- `head.title` fallback when no body header title is present.
- Body background CSS extraction from string `body.background` and precedence of
  string `body.style.background`.
- Decode safety for object-valued `body.style.background` and `body.background`,
  which remain unsupported as rendered backgrounds but no longer block document
  decoding.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.AndroidFooterRenderingTest --no-daemon` fail before Gradle
starts with `Unable to locate a Java Runtime`. Verification should rely on the
GitHub Actions Android job, which provisions Java 17 and runs Gradle tests.
