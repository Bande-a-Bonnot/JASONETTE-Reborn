# Jasonette Reborn

**Build native mobile and web apps using JSON.**

Jasonette lets you describe an entire app — UI, logic, data — in a single JSON document. The runtime renders native components on iOS (SwiftUI), Android (Jetpack Compose), and the web (vanilla TypeScript). Change the JSON, change the app. No recompilation, no app store resubmission.

This is a ground-up revival of the original [Jasonette](https://github.com/nicknish/jasonette-ios) project (5,200+ GitHub stars), rewritten with modern toolchains and a formalized `$jason` protocol specification.

## Status

**Phase 0: Foundation** — Formalizing the `$jason` v2.0 specification, JSON Schema, and project infrastructure.

See the [Roadmap](docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md) for the full plan.

## What is `$jason`?

A `$jason` document is a JSON file that describes a screen:

```json
{
  "$jason": {
    "head": {
      "title": "Hello",
      "actions": {
        "$load": {
          "type": "$render"
        }
      }
    },
    "body": {
      "sections": [
        {
          "items": [
            {
              "type": "label",
              "text": "Hello, World!"
            }
          ]
        }
      ]
    }
  }
}
```

The runtime fetches this JSON from a URL, evaluates templates, renders native components, and executes actions. Navigation between screens is just navigating to another JSON URL.

## Project Structure

```
JASONETTE-Reborn/          # This repo — spec, schema, conformance tests
├── spec/                   # $jason v2.0 specification
│   ├── jason-v2.0.md       # Protocol spec
│   ├── actions.md          # Action catalogue
│   ├── schema/             # JSON Schema (Draft 2020-12)
│   └── conformance/        # Cross-platform test fixtures
├── packages/               # npm workspace packages
├── JASONETTE-iOS/          # iOS app (Swift, iOS 26+)
├── JASONETTE-Android/      # Android app (Kotlin, minSdk 26)
├── Jasonette-Web/          # Web renderer (TypeScript + Vite)
├── Jasonpedia/             # 100+ example $jason documents
└── Jasonette-documentation/# Original docs (reference)
```

## Quick Start

```bash
# Install dependencies
npm install

# Validate Jasonpedia examples against the schema
npm run spec:validate

# Run markdown linting
npm run lint:md
```

## Specification

- [`spec/jason-v2.0.md`](spec/jason-v2.0.md) — The `$jason` protocol specification
- [`spec/actions.md`](spec/actions.md) — Action catalogue with tier assignments
- [`spec/schema/jason.schema.json`](spec/schema/jason.schema.json) — JSON Schema for editor autocompletion

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

Built on the foundation of the original Jasonette by [Ethan](https://github.com/nicknish) and its community of contributors.
