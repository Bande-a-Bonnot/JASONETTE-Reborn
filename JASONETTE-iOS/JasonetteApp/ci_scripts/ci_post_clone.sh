#!/bin/bash
set -euo pipefail

# Xcode Cloud runs this after cloning, before resolving dependencies.
# We use it to install Tuist and generate the Xcode workspace.

echo "--- Installing mise + Tuist"
brew install mise
eval "$(mise activate bash)"
mise install

echo "--- Generating Xcode project"
mise exec -- tuist install
mise exec -- tuist generate --no-open

echo "--- Done. Xcode Cloud will now build the generated workspace."
