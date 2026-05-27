# Contributing to Jasonette Reborn

Thank you for your interest in contributing. This guide is for anyone who wants to help — whether you write code, file bugs, improve the spec, or write documentation.

## Ways to Contribute

Not all contributions require code:

- **Port a Jasonpedia example** to the conformance test suite format
- **File a spec ambiguity issue** when the `$jason` protocol behavior is unclear
- **Report bugs** on a specific platform (iOS, Android, Web)
- **Improve documentation** or add tutorials
- **Review pull requests** and provide feedback

## Development Setup

### Prerequisites

- Node.js 20+
- npm 10+

### Install

```bash
git clone https://github.com/Bande-a-Bonnot/JASONETTE-Reborn.git
cd JASONETTE-Reborn
npm install
```

### Verify Setup

```bash
npm run spec:validate  # Validate Jasonpedia against JSON Schema
npm run lint:md        # Lint markdown files
```

### Platform-Specific Setup

**Web renderer:** See `Jasonette-Web/README.md` (requires Node.js 20+).

**iOS:** Requires Xcode 26+, Swift 6, iOS 26+ target. Open `JASONETTE-iOS/` in Xcode.

**Android:** Requires Android Studio, Kotlin, minSdk 26. Open `JASONETTE-Android/` in Android Studio.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) with platform scopes:

```
feat(spec): add mixin origin policy to security model
fix(web): correct $render template option handling
test(conformance): add adversarial prototype pollution fixture
docs: update README with quick start guide
chore(ci): add markdown linting workflow
```

**Scopes:** `spec`, `web`, `ios`, `android`, `conformance`, `ci`, `docs`

Commit early and often. Favor atomic commits — one logical change per commit.

## Branching Model

- `main` — stable, always passes CI
- `feat/<name>` — feature branches
- `fix/<name>` — bug fix branches
- `milestone/<name>` — milestone branches (used for phased development)

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with atomic commits
3. Run tests locally: `npm test`
4. Run linting: `npm run lint:md`
5. Open a PR against `main`
6. Fill out the PR template completely
7. Wait for CI and code review
8. Address review comments
9. Once approved, the maintainer merges

### PR Review Policy

- Maximum 3 review cycles per PR (push → review → address → repeat)
- After 3 rounds, the maintainer makes a judgment call: merge, split, or close
- Automated reviewer false positives are dismissed with an explanatory reply

## Issue Reporting

### Bugs

Use the **Bug Report** template. Include:
- Platform (iOS / Android / Web)
- Steps to reproduce
- Expected vs actual behavior
- JSON document that triggers the bug (if applicable)

### Spec Ambiguities

Use the **Spec Ambiguity** template. This is for cases where the `$jason` protocol behavior is unclear or inconsistent across platforms. These are not bugs — they are specification gaps.

### Feature Requests

Use the **Feature Request** template. Describe the use case, not just the solution.

## Testing

- Use a TDD approach: write tests first, then code
- Run tests regularly to tighten your feedback loop
- Use UUIDv7 for all IDs

## Code of Conduct

This project follows the [Contributor Covenant v2.1](CODE_OF_CONDUCT.md). Be respectful and constructive.
