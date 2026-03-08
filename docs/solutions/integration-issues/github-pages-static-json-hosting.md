---
title: "GitHub Pages 404 for static JSON files: enable Pages + add .nojekyll"
date: 2026-03-08
category: integration-issues
tags: [github-pages, json, jekyll, jasonette, static-hosting]
module: Jasonpedia
symptom: "App shows 404 when fetching demo JSON from bande-a-bonnot.github.io"
---

# GitHub Pages 404 for Static JSON Files

## Problem

The Jasonette app loads its UI from a JSON file hosted at `https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json`. On device, the app showed a 404. The JSON file existed in the repo at `Jasonpedia/demo.json`, but wasn't being served.

Additionally, `demo.json` contains internal links to other JSON files on the same domain (core/index.json, view/index.json, etc.), so switching to `raw.githubusercontent.com` for just the entry URL wouldn't fix the sub-navigation.

## Root Cause

Two issues:

1. **GitHub Pages was not enabled** for the repository. No Pages site existed — the API returned 404 for the `/pages` endpoint, and no `gh-pages` branch existed.

2. **Jekyll processing** — Even after enabling Pages, the first build failed with "Page build failed." GitHub Pages runs Jekyll by default, which is unnecessary and can fail on large repos with non-Jekyll content.

## What Doesn't Work

### Switching to raw.githubusercontent.com

```
https://raw.githubusercontent.com/bande-a-bonnot/JASONETTE-Reborn/main/Jasonpedia/demo.json
```

This works for the entry URL, but demo.json contains dozens of internal `href` links to other JSON files all using the `bande-a-bonnot.github.io` domain. You'd have to rewrite every URL in every JSON file.

### Enabling Pages without .nojekyll

GitHub Pages tries to run Jekyll on the repo. For a large repo with non-Jekyll content, this fails silently with "Page build failed."

## What Works

### Step 1: Enable GitHub Pages via API

```bash
# Create the Pages site
gh api repos/OWNER/REPO/pages -X POST \
  --input - <<'EOF'
{
  "build_type": "legacy",
  "source": { "branch": "main", "path": "/" }
}
EOF
```

Or if already created with `build_type: workflow`, switch to legacy:

```bash
gh api repos/OWNER/REPO/pages -X PUT \
  --input - <<'EOF'
{
  "build_type": "legacy",
  "source": { "branch": "main", "path": "/" }
}
EOF
```

### Step 2: Add .nojekyll

Create an empty `.nojekyll` file at the repo root. This tells GitHub Pages to skip Jekyll and serve files as static content:

```bash
touch .nojekyll
git add .nojekyll
git commit -m "Add .nojekyll to fix GitHub Pages build"
git push
```

### Step 3: Trigger build

Legacy mode builds on push. If the repo is clean, trigger manually:

```bash
gh api repos/OWNER/REPO/pages/builds -X POST
```

### Step 4: Verify

```bash
# Check build status
gh api repos/OWNER/REPO/pages/builds/latest -q '.status'
# Expected: "built"

# Check site status
gh api repos/OWNER/REPO/pages -q '.status'
# Expected: null (after successful build) or "built"
```

## Key Insight

`build_type: "legacy"` deploys directly from the branch — no GitHub Actions workflow needed. `build_type: "workflow"` requires a `.github/workflows/` file for Pages deployment. For serving static files, legacy is simpler.

## Prevention

- When a project serves static assets (JSON, images) via GitHub Pages, always include `.nojekyll` in the repo root
- Verify Pages is enabled before hardcoding `*.github.io` URLs in app code
- Use `gh api repos/OWNER/REPO/pages` to check Pages status programmatically

## Related

- `docs/solutions/integration-issues/ios-ci-cd-provider-tradeoffs.md`
- `docs/solutions/architecture-patterns/tuist-spm-multiplatform-testflight.md`
