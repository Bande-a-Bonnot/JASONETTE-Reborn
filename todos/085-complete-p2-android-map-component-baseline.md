---
id: "019f30a5-ddd9-702d-a3ee-bcaaace7401a"
status: completed
priority: p2
issue_id: "085"
tags: [android, parity, components, map]
dependencies: ["068", "082"]
completed_at: "2026-07-05"
---

# Complete Android map component baseline

## Outcome

Android now has a deterministic `type: "map"` rendering baseline instead of the
previous visible unsupported placeholder:

- `JasonComponent` decodes legacy map `region` and `pins` payloads.
- `ComponentView` routes `type: "map"` to `MapComponent`.
- `MapComponent` renders a Material map summary card with authored region meters
  and pin title/description/coordinate labels, so Jasonpedia map fixtures expose
  meaningful authored map content in the current Compose renderer.
- Pin action/href fields are preserved in the model for future interactive map
  work.

This is not full legacy Android Google Maps parity. Native map tiles, camera
movement, marker interaction, info-window actions, API-key behavior, and map touch
interop remain future work.

## Verification

Added JVM coverage for pure helpers and fixture decoding:

- `Jasonpedia/view/component/map/index.json` decodes map components in both
  section header and item positions.
- Region labels preserve authored `coord`, `width`, and `height` values.
- Pin labels preserve title, description, and coordinate values.
- Missing pin titles fall back to deterministic `Pin N` labels.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.AndroidFooterRenderingTest --no-daemon` fail before Gradle
starts with `Unable to locate a Java Runtime`.

Initial implementation commit `dc9c9035a5e90c9958bd439c251eb674ccb5701d` failed
GitHub Actions Android build in run `28730128564` because of an invalid
`kotlinx.serialization.json.content` import. Follow-up commit
`e8b9b1361bd606c8aa2884f26abdd0fb1f133860` removed that import.

GitHub Actions CI run `28733880172` passed for exact head SHA
`e8b9b1361bd606c8aa2884f26abdd0fb1f133860`. Its Android job provisioned Java
17 and completed successfully.
