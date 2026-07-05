---
id: "019f302b-4388-7abe-b7a7-3de56cc6bca1"
status: completed
priority: p1
issue_id: "080"
tags: [android, parity, render, templates, actions]
dependencies: ["068", "076", "079"]
completed_at: "2026-07-05"
---

# Complete Android `$render` template/data baseline

## Outcome

Android now supports a broader legacy `$render` baseline:

- `head.templates` decodes as an arbitrary JSON object instead of only a typed
  `body` field, so named templates such as `detail` can be selected.
- `$render` passes templated `options.template` and structured `options.data` to
  the render handler.
- `JasonetteViewModel` tracks the current render template/data through a pure
  `RenderSelection` helper and re-renders the active document with that
  selection.
- Subsequent `$render` calls that omit `options.data` preserve the active render
  payload until reload, matching the legacy current-`$jason` expectation more
  closely.
- `JasonetteDocumentRenderer` renders the selected named template and falls back
  to `body` when a named template is missing.
- Render `options.data` is exposed as `$jason` and its object fields are also
  available as top-level template values.

This is a focused action/render graph parity slice. Legacy action arrays,
`$lambda` payload rules, `$return.*`, and success-payload promotion into `$render`
without authored `options.data` remain future work.

## Verification

Added JVM coverage for:

- `$render` passing templated `template` and structured `data` options to the
  dispatcher render handler.
- Pure `RenderSelection` payload preservation, explicit null-data clearing, and
  reset behavior.
- Rendering a selected named template with `options.data` exposed as `$jason` and
  top-level fields.
- Falling back to the body template when a named template is missing.
- Existing legacy include loader tests updated for arbitrary-template decoding.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `cd JASONETTE-Android/JasonetteApp && ./gradlew test --tests
com.jasonette.ActionDispatcherTest --tests com.jasonette.JasonetteDocumentRendererTest
--tests com.jasonette.DocumentLoaderTest --tests com.jasonette.RenderSelectionTest
--no-daemon` fails before Gradle starts
with `Unable to locate a Java Runtime`. Verification should rely on the GitHub
Actions Android job, which provisions Java 17 and runs Gradle tests.
