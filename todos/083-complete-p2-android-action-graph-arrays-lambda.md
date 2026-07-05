---
id: "019f308d-da2a-7e63-8ade-64b8975ffb10"
status: completed
priority: p2
issue_id: "083"
tags: [android, parity, actions, lambda, templates]
dependencies: ["068", "080"]
completed_at: "2026-07-05"
---

# Complete Android action graph arrays and lambda baseline

## Outcome

Android action dispatch now handles a broader legacy Jasonette action graph:

- `JasonAction` decodes raw `options` as `JsonElement`, preserving object,
  array, string, and primitive option shapes used by legacy `$lambda` and utility
  actions.
- `success` and `error` continuations can decode as either a single action or an
  action array while keeping the raw JSON for conditional rendering at dispatch
  time.
- Action arrays execute sequentially, so later actions template against state
  changes made by earlier actions.
- Conditional action arrays support split `{{#if}}` / `{{#elseif}}` /
  `{{#else}}` branches and skip unmatched standalone conditional branches.
- Whole-tree option templating preserves recursive key and value interpolation,
  including string options like `"{{$jason}}"` that render to structured objects.
- `$lambda` resolves named `head.actions`, passes `options.options` as a temporary
  `$jason` payload, restores the prior payload after the callee, and supports
  `$return.success` / `$return.error` payloads for caller success/error chains.
- Trigger-only actions pass authored `options` as a temporary `$jason` payload and
  also honor `$return.success` / `$return.error` from named actions.
- TemplateEngine split conditional arrays gained `#elseif` support plus scoped
  nested conditional behavior.

This is still a baseline: richer legacy `$lambda` event semantics and broader
native action families remain future work.

## Verification

Added JVM test coverage in:

- `ActionDispatcherTest` for `$lambda` payload passing/restoration,
  `$return.success`, `$return.error`, trigger payloads, sequential action arrays,
  conditional success arrays, lambda conditional fallback actions, string utility
  options, recursive templated option keys/values, and serializer array output.
- `TemplateEngineTest` for split `#if`/`#else`, `#elseif`, sibling preservation,
  and nested conditional scoping.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew
compileDebugKotlin testDebugUnitTest --tests com.jasonette.ActionDispatcherTest
--tests com.jasonette.TemplateEngineTest --no-daemon` fail before Gradle starts
with `Unable to locate a Java Runtime`. Verification should rely on GitHub
Actions Android CI, which provisions Java 17 and runs Gradle build/tests.
