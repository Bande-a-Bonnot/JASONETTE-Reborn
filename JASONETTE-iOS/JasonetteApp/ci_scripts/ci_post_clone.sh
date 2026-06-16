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
export JASONETTE_GIT_COMMIT="${CI_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
export JASONETTE_GIT_BRANCH="${CI_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
export JASONETTE_CI_WORKFLOW="${CI_WORKFLOW:-local}"
export JASONETTE_CI_BUILD_NUMBER="${CI_BUILD_NUMBER:-local}"
export JASONETTE_BUILD_GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf 'commit=%s\nbranch=%s\nworkflow=%s\nbuild=%s\ngenerated=%s\n' \
  "$JASONETTE_GIT_COMMIT" \
  "$JASONETTE_GIT_BRANCH" \
  "$JASONETTE_CI_WORKFLOW" \
  "$JASONETTE_CI_BUILD_NUMBER" \
  "$JASONETTE_BUILD_GENERATED_AT"

echo "--- Generating Xcode project"
mise exec -- tuist install
mise exec -- tuist generate --no-open

echo "--- Done. Xcode Cloud will now build the generated workspace."
