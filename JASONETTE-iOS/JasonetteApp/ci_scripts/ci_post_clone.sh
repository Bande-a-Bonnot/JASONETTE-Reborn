#!/bin/bash
set -euo pipefail

# Xcode Cloud runs this from ci_scripts/. cd to the JasonetteApp root
# where Project.swift and Package.swift live.
cd "$(dirname "$0")/.."

echo "--- Installing mise + Tuist"
brew install mise
eval "$(mise activate bash)"
mise install

echo "--- Capturing build provenance"
git_commit="${CI_COMMIT:-$(git rev-parse HEAD 2>/dev/null || true)}"
git_branch="${CI_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)}"
ci_workflow="${CI_WORKFLOW:-Xcode Cloud}"
ci_build_number="${CI_BUILD_NUMBER:-}"

if [[ -n "$git_commit" ]]; then export JASONETTE_GIT_COMMIT="$git_commit"; fi
if [[ -n "$git_branch" ]]; then export JASONETTE_GIT_BRANCH="$git_branch"; fi
export JASONETTE_CI_WORKFLOW="$ci_workflow"
if [[ -n "$ci_build_number" ]]; then export JASONETTE_CI_BUILD_NUMBER="$ci_build_number"; fi
export JASONETTE_BUILD_GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf 'commit=%s\nbranch=%s\nworkflow=%s\nbuild=%s\ngenerated=%s\n' \
  "${JASONETTE_GIT_COMMIT:-unresolved}" \
  "${JASONETTE_GIT_BRANCH:-unresolved}" \
  "$JASONETTE_CI_WORKFLOW" \
  "${JASONETTE_CI_BUILD_NUMBER:-defer-to-CURRENT_PROJECT_VERSION}" \
  "$JASONETTE_BUILD_GENERATED_AT"

echo "--- Generating Xcode project"
mise exec -- tuist install
mise exec -- tuist generate --no-open

echo "--- Done. Xcode Cloud will now build the generated workspace."
