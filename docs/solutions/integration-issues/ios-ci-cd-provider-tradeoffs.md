---
title: "iOS CI/CD for public repos: why Xcode Cloud wins over GitHub Actions, Buildkite, and GetMac"
date: 2026-03-07
category: integration-issues
tags: [ci-cd, xcode-cloud, github-actions, buildkite, getmac, testflight, signing, ios]
module: JASONETTE-iOS
symptom: "Need to ship iOS app to TestFlight from a public repo without leaking signing credentials"
---

# iOS CI/CD for Public Repos: Xcode Cloud Wins

## Problem

Public repos need iOS CI/CD (archive → TestFlight) but signing credentials (distribution certificate, App Store Connect API key, provisioning profiles) must never be exposed. Every CI provider except Apple's own requires you to manage these secrets yourself.

## Options Evaluated (in order tried)

### 1. GitHub Actions + self-hosted runner

Same pattern as kumbaya and ten-a-day (Bazel projects).

**Problem:** GitHub org secrets are not available to public repos by default. Workaround: GitHub Environments with branch protection. But this means managing 5 secrets, a Gemfile, Fastlane lanes, and a self-hosted macOS runner.

**Rejected:** Too much infrastructure for what should be simple.

### 2. Buildkite + GetMac plugin

GetMac provisions ephemeral macOS VMs via a Buildkite plugin.

**Problem:** GetMac does NOT provide a Buildkite agent. You still need your own agent running somewhere. The plugin SSHs from your agent into their VM. If you're setting up a Mac Mini as a Buildkite agent anyway, GetMac adds complexity without removing the need for your own infrastructure.

**Rejected:** Doesn't solve the actual problem.

### 3. Xcode Cloud

**Chosen.** Apple handles everything: signing, provisioning profiles, certificates, archiving, TestFlight upload, dSYMs. No secrets in the repo. No env vars. No Fastlane. No self-hosted runner.

**Setup:** App Store Connect → Xcode Cloud → Create Workflow → point to repo → select scheme → done.

**Only requirement:** A `ci_scripts/ci_post_clone.sh` script that installs Tuist and generates the workspace before Xcode Cloud tries to build:

```bash
#!/bin/bash
set -euo pipefail
brew install mise
eval "$(mise activate bash)"
mise install
mise exec -- tuist install
mise exec -- tuist generate --no-open
```

That's it. 12 lines replace 5 secrets + Fastlane + GitHub Actions YAML + self-hosted runner.

## Why This Only Works for Swift/Xcode Projects

Kumbaya and ten-a-day use Bazel, which Xcode Cloud doesn't support. They need GitHub Actions + Fastlane + self-hosted runner because Xcode Cloud can only build Xcode projects and SPM packages. Tuist-generated workspaces are just Xcode projects, so they work fine.

## The Progression

| Attempt | Files | Secrets | Runner | Outcome |
|---------|-------|---------|--------|---------|
| GitHub Actions | 4 (workflow + Gemfile + Fastfile + Appfile) | 5 | Self-hosted | Works but heavy |
| Buildkite + GetMac | 4 (pipeline + hooks + step) + Fastlane | 6 | Still need your own agent | Rejected |
| Xcode Cloud | 1 (ci_post_clone.sh) | 0 | Apple's | Correct answer |

## Key Lesson

Don't reflexively reach for the CI tool you already know. The right tool depends on the build system. For pure Xcode/SPM projects, Xcode Cloud eliminates entire categories of problems (secret management, runner provisioning, signing) that other providers force you to solve yourself.

Also: Fastlane lanes are provider-agnostic. If you write them first, switching providers only means changing the pipeline YAML. But sometimes the right move is to not need Fastlane at all.

## Related

- `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`
- `docs/solutions/build-errors/tuist4-duplicate-key-local-package.md`
