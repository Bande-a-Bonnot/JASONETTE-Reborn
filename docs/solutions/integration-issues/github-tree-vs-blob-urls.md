---
title: "GitHub /tree/ vs /blob/ URL paths in bulk migrations"
category: integration-issues
tags: [github, url-migration, sed, bulk-replace]
module: Jasonpedia
symptom: "GitHub returns 404 for URLs pointing to individual JSON files"
root_cause: "Bulk find-and-replace converted file URLs to /tree/ paths instead of /blob/"
---

# GitHub /tree/ vs /blob/ URL paths in bulk migrations

## Problem

During the Jasonpedia URL migration (Phase 4), a two-step `sed` replacement
was used to update all GitHub URLs from the original `Jasonette` org to
`Bande-a-Bonnot/JASONETTE-Reborn`.

The first replacement was correct:

```
github.com/Jasonette/Jasonpedia/blob/gh-pages  ->  github.com/Bande-a-Bonnot/JASONETTE-Reborn/blob/main/Jasonpedia
```

A second, broader replacement caught remaining org-level references:

```
github.com/Jasonette  ->  github.com/Bande-a-Bonnot
```

This accidentally converted URLs that already had `/tree/` paths pointing to
specific JSON files. The resulting URLs looked like:

```
github.com/Bande-a-Bonnot/JASONETTE-Reborn/tree/main/Jasonpedia/demo.json
```

GitHub returns **404** for these URLs because `/tree/` is only valid for
directories, not individual files.

## Root Cause

GitHub uses two distinct URL path prefixes with different semantics:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `/tree/branch/path` | Browse a **directory** | `/tree/main/Jasonpedia/` |
| `/blob/branch/path` | View an individual **file** | `/blob/main/Jasonpedia/demo.json` |

Bulk find-and-replace operates on raw text and has no understanding of this
semantic distinction. When the org-level replacement ran, it updated the
hostname and org portions of the URL but left the path prefix untouched.
URLs that happened to use `/tree/` for file paths were not corrected to
`/blob/`.

## Solution

A targeted fix was applied after the initial migration to correct only the
affected pattern:

```bash
find Jasonpedia -name "*.json" -exec sed -i '' \
  's|/tree/main/Jasonpedia/\([^"]*\.json\)|/blob/main/Jasonpedia/\1|g' {} +
```

This matches any `/tree/main/Jasonpedia/...*.json` pattern and rewrites the
path prefix to `/blob/`, leaving directory-level `/tree/` URLs intact.

## Key Insight

Gemini's automated code review caught this issue on PR #6 -- after the PR was
already merged. This demonstrates the value of reviewing automated feedback
even after merge. The fix was applied in a subsequent PR rather than discarded
as stale.

Automated reviewers can surface issues that humans miss in large diffs,
especially mechanical changes like bulk URL replacement where the volume of
changes makes manual verification impractical.

## Prevention

When performing bulk URL migrations, use a layered strategy to avoid
conflating file and directory URLs:

1. **Separate file-level from directory-level URLs.** Handle `/blob/` and
   `/tree/` replacements independently so each retains the correct prefix.

2. **Use a two-pass approach:**
   - First pass: replace the org and repo segments of the URL.
   - Second pass: verify that path prefixes (`/tree/` vs `/blob/`) match the
     resource type (directory vs file).

3. **Add a validation step after migration.** Run a check for mismatched URLs
   before committing:

   ```bash
   grep -r '/tree/.*\.json' --include='*.json' | grep github
   ```

   Any results indicate a file URL that incorrectly uses `/tree/` and needs
   correction to `/blob/`.
