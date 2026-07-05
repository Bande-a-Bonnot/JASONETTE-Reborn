---
id: "019f31bd-ef31-7e55-8e96-dd81710e50c7"
status: completed
priority: p2
issue_id: "086"
tags: [android, parity, actions, convert, csv, rss]
dependencies: ["068", "076", "083"]
completed_at: "2026-07-05"
---

# Complete Android `$convert.csv` / `$convert.rss` action baseline

## Outcome

Android now recognizes baseline legacy conversion actions used by the Jasonpedia
CSV/RSS template fixtures:

- `$convert.csv` reads templated `options.data` or the current string `$jason`
  payload and stores parsed row dictionaries under `$jason`.
- CSV parsing supports header-derived object keys, blank-row skipping, quoted
  commas, and escaped double quotes.
- `$convert.rss` reads templated `options.data` or the current string `$jason`
  payload and stores parsed item dictionaries under `$jason`.
- RSS parsing supports the current iOS/Jasonpedia baseline fields: `title`,
  `author`, `description`, `url`, and nested `image.url` from media/enclosure
  tags, with common XML entity decoding.
- Normal success chains continue after conversion, so `$convert.*` followed by
  `$render` can render converted payloads.

This is not full legacy Android converter parity. The old Android reference used
JavaScript helpers/feedparser and handled a broader set of CSV/RSS/Atom shapes;
Atom feeds, richer feed metadata, tab-delimited/HTML-preprocessed CSV, and
legacy feedparser-specific keys remain future work.

## Verification

Added JVM coverage in `ActionDispatcherTest` for:

- `$convert.csv` storing row objects under `$jason` and continuing to `$render`.
- Quoted CSV fields with commas and escaped quotes.
- `$convert.rss` storing item fields under `$jason`, decoding CDATA/XML entities,
  extracting `dc:creator`, `description`, `link`, and `media:content` image URL,
  and continuing to `$render`.
- Conversion fallback to current string `$jason` payload when `options.data` is
  absent.

A read-only reviewer subagent checked the uncommitted implementation for compile
risk and action semantics. It found no critical issues, noted the intentional
baseline-vs-legacy gaps above, and suggested numeric entity coverage; `&#39;`
coverage was added before commit.

Local Android Gradle execution remains blocked on this host by the missing Java
runtime: `java -version` and `cd JASONETTE-Android/JasonetteApp && ./gradlew test
--tests com.jasonette.ActionDispatcherTest --no-daemon` fail before Gradle starts
with `Unable to locate a Java Runtime`.

GitHub Actions CI run `28736279941` passed for exact head SHA
`1212ac2210868380b5c7f0ce942ea71f87216aea`. Its Android job provisioned Java 17
and completed successfully.
