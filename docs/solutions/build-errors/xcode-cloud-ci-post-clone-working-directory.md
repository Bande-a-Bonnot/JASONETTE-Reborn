---
title: "Xcode Cloud ci_post_clone.sh fails: Tuist manifest not found because script runs from ci_scripts/"
date: 2026-03-08
category: build-errors
tags: [xcode-cloud, tuist, ci-cd, ci-post-clone, working-directory]
module: JasonetteApp
symptom: "Manifest not found at path /Volumes/workspace/repository/.../ci_scripts"
---

# Xcode Cloud: ci_post_clone.sh Runs from Wrong Directory

## Problem

Xcode Cloud ci_post_clone.sh fails with:

```
✖ Error
  Manifest not found at path /Volumes/workspace/repository/JASONETTE-iOS/JasonetteApp/ci_scripts
```

Tuist expects to find `Project.swift` and `Package.swift` in the current working directory, but it's looking in `ci_scripts/`.

## Root Cause

Xcode Cloud executes `ci_scripts/ci_post_clone.sh` with the working directory set to the `ci_scripts/` directory itself — NOT the project root, and NOT the repository root. Tuist commands (`tuist install`, `tuist generate`) need to run from the directory containing `Project.swift` and `Package.swift`.

## What Doesn't Work

### Assuming the working directory is the project root

```bash
#!/bin/bash
set -euo pipefail
# WRONG: assumes cwd is JasonetteApp/, but it's actually ci_scripts/
brew install mise
eval "$(mise activate bash)"
mise install
mise exec -- tuist install
mise exec -- tuist generate --no-open
```

## What Works

Add `cd "$(dirname "$0")/.."` at the top of the script to navigate from `ci_scripts/` to the project root:

```bash
#!/bin/bash
set -euo pipefail

# Xcode Cloud runs this from ci_scripts/. cd to the JasonetteApp root
# where Project.swift and Package.swift live.
cd "$(dirname "$0")/.."

echo "--- Installing mise + Tuist"
brew install mise
eval "$(mise activate bash)"
mise install

echo "--- Generating Xcode project"
mise exec -- tuist install
mise exec -- tuist generate --no-open

echo "--- Done. Xcode Cloud will now build the generated workspace."
```

`$(dirname "$0")/..` resolves to the parent of the script's own directory — reliable regardless of how Xcode Cloud sets the working directory.

## Xcode Cloud ci_scripts Directory Reference

Xcode Cloud looks for scripts at specific paths relative to the Xcode project/workspace:

| Script | Runs when | Working directory |
|--------|-----------|-------------------|
| `ci_scripts/ci_post_clone.sh` | After cloning, before resolving dependencies | `ci_scripts/` |
| `ci_scripts/ci_pre_xcodebuild.sh` | Before xcodebuild | `ci_scripts/` |
| `ci_scripts/ci_post_xcodebuild.sh` | After xcodebuild | `ci_scripts/` |

All scripts run with cwd set to `ci_scripts/`, NOT the project root.

## Prevention

- Always start Xcode Cloud ci_scripts with `cd "$(dirname "$0")/.."` if you need to run project-level tools
- Test scripts locally: `cd ci_scripts && bash ci_post_clone.sh` — if it fails, Xcode Cloud will too
- Use absolute paths or `$CI_PRIMARY_REPOSITORY_PATH` environment variable as alternative

## Related

- `docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md`
- `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`
