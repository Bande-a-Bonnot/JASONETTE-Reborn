---
title: "iOS CI/CD provider tradeoffs: GitHub Actions vs Buildkite vs GetMac for public repos"
date: 2026-03-07
category: integration-issues
tags: [ci-cd, github-actions, buildkite, getmac, testflight, signing, ios]
module: JASONETTE-iOS
symptom: "Need to ship iOS app to TestFlight from a public repo without leaking signing credentials"
---

# iOS CI/CD Provider Tradeoffs for Public Repos

## The Problem

Public repos need iOS CI/CD (archive → TestFlight) but signing credentials (distribution certificate, App Store Connect API key) must never be exposed.

## Options Evaluated

### GitHub Actions + self-hosted runner (getmac-tahoe)

**Chosen for now.** Same pattern as kumbaya and ten-a-day.

- Org secrets not available to public repos by default
- **Fix:** Use GitHub Environments (e.g. `production`) — environment secrets are available to public repos, scoped to specific branches
- Self-hosted runner already exists and has macOS + Xcode
- Fastlane handles signing (import P12, download profile, archive, upload)
- Proven: 2 sibling projects ship to TestFlight this way

### Buildkite + GetMac plugin

**Rejected.** GetMac provisions ephemeral macOS VMs but does NOT provide a Buildkite agent. You still need your own agent running somewhere to orchestrate. The GetMac plugin SSHs from your agent into their VM.

If you're setting up a Buildkite agent on a Mac Mini anyway, you might as well run builds directly on it — GetMac adds complexity without removing the need for your own infrastructure.

GetMac would make sense if they provided a fully managed Buildkite agent, but they don't.

### Buildkite + self-hosted agent (no GetMac)

**Deferred.** Would require setting up a Buildkite agent on a Mac. Viable but no advantage over GitHub Actions for this use case. Secrets handled via `buildkite-agent secret get` instead of GitHub's encrypted secrets — arguably cleaner API.

## Signing Credentials Required

Same 5 secrets across all approaches:

| Secret | Format |
|--------|--------|
| `APPLE_DISTRIBUTION_CERTIFICATE_P12` | Base64 `.p12` export |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | String |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | String |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | UUID |
| `APP_STORE_CONNECT_API_KEY_KEY` | Base64 `.p8` key |

**Apple Distribution** certificate, not Apple Development. Development certs are for local device builds; distribution certs are for App Store / TestFlight.

Also needed in Apple Developer Portal: explicit App ID + App Store distribution provisioning profile matching the bundle ID.

## Key Lesson

The Fastlane lanes (`fetch_signing`, `build`, `upload_testflight`) are provider-agnostic. Only the pipeline YAML and secret injection mechanism change between providers. Write the Fastlane first, worry about the CI provider second.

## Related

- `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`
- `docs/solutions/ci-self-hosted-runner-getmac.md`
