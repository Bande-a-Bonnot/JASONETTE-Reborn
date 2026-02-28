---
title: "Self-hosted CI runner getmac-tahoe"
category: configuration-fixes
tags: [ci, github-actions, self-hosted-runner, macos]
module: CI
symptom: "CI jobs stuck in 'queued' state"
root_cause: "Self-hosted runner not configured for new repos"
---

## Context

The `Bande-a-Bonnot` org uses a self-hosted macOS runner labeled
`getmac-tahoe` instead of GitHub-hosted runners. This is configured at
the org level.

## Gotcha

When creating a new repo in the org, the self-hosted runner may not
automatically be available. CI jobs will queue indefinitely until the
runner is added to the repo's runner group.

## Fix

1. Go to GitHub org settings > Actions > Runner groups
2. Ensure `getmac-tahoe` runner group includes the new repo
3. Or set the runner group to "All repositories"

## CI Configuration

All jobs use `runs-on: getmac-tahoe` — no `ubuntu-latest` or `macos-15`.
