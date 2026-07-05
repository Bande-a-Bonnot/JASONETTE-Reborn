---
id: "019f309a-1640-7a08-ba5e-a918d5f66d76"
status: completed
priority: p2
issue_id: "084"
tags: [android, parity, components, html, webview]
dependencies: ["068", "082"]
completed_at: "2026-07-05"
---

# Complete Android HTML component inline CSS baseline

## Outcome

Android now renders authored `type: "html"` components with a native `WebView`
baseline instead of the previous visible unsupported placeholder:

- `JasonComponent` decodes the legacy `css` field used by Jasonpedia HTML
  component fixtures.
- `ComponentView` routes `type: "html"` to `HtmlComponent`.
- `HtmlComponent` uses Compose `AndroidView` with a hardened baseline `WebView`.
- Inline `text` content is loaded with authored `css` prepended as a `<style>`
  tag, matching the Jasonpedia HTML component surface used by current web parity
  work.
- URL-backed HTML is allowed only for `http`/`https` URLs; unsafe schemes are
  ignored rather than loaded.
- A stable load key avoids reloading the WebView on unrelated recompositions.

This is not full legacy HTML bridge parity. Jason bridge callbacks, `$default`
interaction semantics, webcontainer agent services, and richer lifecycle behavior
remain future work.

## Verification

Added JVM coverage for pure helpers and fixture decoding:

- Inline CSS is prepended before HTML text.
- URL helper accepts only `http`/`https` and produces stable load keys.
- `Jasonpedia/view/component/html/index.json` decodes as an `html` component,
  preserves authored `css`/`text`, and produces source containing the inline
  `<style>` plus fixture content.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.AndroidFooterRenderingTest --no-daemon` fail before Gradle
starts with `Unable to locate a Java Runtime`. Verification should rely on the
GitHub Actions Android CI job, which provisions Java 17 and runs Gradle
build/tests.
