---
title: "GitHub Actions jobs queue forever on getmac-tahoe: self-hosted runner labels don't work like hosted runners"
date: 2026-03-08
category: integration-issues
tags: [github-actions, getmac, ci-cd, runners, self-hosted]
module: JASONETTE-Reborn
symptom: "GitHub Actions jobs stuck in 'queued' state for 24+ hours, consuming 30,000+ seconds"
---

# GitHub Actions Jobs Queue Forever on GetMac Runner Labels

## Problem

GitHub Actions CI jobs queue indefinitely — one job ran for 30,000+ seconds (8+ hours) without executing. The workflow uses `runs-on: getmac-tahoe` for all jobs, but no runner with that label is connected.

## Root Cause

`getmac-tahoe` is a GetMac ephemeral VM label, NOT a GitHub-hosted runner. GetMac provides macOS VMs but requires you to have your own CI agent (Buildkite or GitHub Actions self-hosted runner) that SSHs into the VM. Without an active self-hosted runner registered with the `getmac-tahoe` label, GitHub Actions queues the job forever until it hits the 6-hour timeout.

The workflow had 6 jobs all using `runs-on: getmac-tahoe`:
- `changes` (path filter)
- `template-engine` (Node.js)
- `web-renderer` (Node.js)
- `ios` (Swift)
- `android` (Java/Gradle)
- `lint` (markdownlint)

Every push to main queued all 6 jobs. Most of them don't even need macOS.

## What Doesn't Work

### Using GetMac labels directly in runs-on

```yaml
# QUEUES FOREVER — no self-hosted runner registered
jobs:
  build:
    runs-on: getmac-tahoe
```

GetMac is NOT a drop-in replacement for GitHub-hosted runners. It provisions VMs that you SSH into from your own runner.

## What Works

Replace `getmac-tahoe` with GitHub-hosted runners:

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest      # Path filtering — no macOS needed

  template-engine:
    runs-on: ubuntu-latest      # Node.js — no macOS needed

  web-renderer:
    runs-on: ubuntu-latest      # Node.js — no macOS needed

  ios:
    runs-on: macos-14           # Swift needs macOS + Xcode

  android:
    runs-on: ubuntu-latest      # Gradle/Java — no macOS needed

  lint:
    runs-on: ubuntu-latest      # markdownlint — no macOS needed
```

Only the iOS job actually needs macOS (for `swift build` / `swift test`). Everything else runs fine on Ubuntu, which is faster to provision and cheaper.

## Runner Selection Guide

| Job type | Runner | Why |
|----------|--------|-----|
| Node.js (npm, TypeScript) | `ubuntu-latest` | Cross-platform, fastest provisioning |
| Swift / Xcode | `macos-14` | Requires Xcode toolchain |
| Java / Gradle / Android | `ubuntu-latest` | Cross-platform |
| Linting (markdown, etc.) | `ubuntu-latest` | No platform dependency |
| Path filtering | `ubuntu-latest` | Just git operations |

## Prevention

- Never use self-hosted runner labels without confirming the runner is online: Settings → Actions → Runners
- Default to `ubuntu-latest` unless the job explicitly needs macOS or Windows
- For iOS CI (not signing/archiving), `macos-14` works. For signing + TestFlight, use Xcode Cloud instead.
- Set `concurrency.cancel-in-progress: true` to prevent queue buildup

## Related

- `docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md`
