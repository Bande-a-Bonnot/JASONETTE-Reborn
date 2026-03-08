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
