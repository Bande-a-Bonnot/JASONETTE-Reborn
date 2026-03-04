#!/bin/bash
set -euo pipefail

# --- Tool setup (ephemeral GetMac VM) ---
echo "--- :toolbox: Installing tools"
brew install mise
eval "$(mise activate bash)"

cd JASONETTE-iOS/JasonetteApp
mise install

# --- Version ---
VERSION=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 | sed 's/^v//' || true)
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILDKITE_BUILD_NUMBER:-1}"
echo "--- Version: ${VERSION} (build ${BUILD_NUMBER})"

# --- Ruby + Fastlane ---
echo "--- :ruby: Installing Ruby dependencies"
bundle install --jobs 4 --retry 3

# --- Signing ---
echo "--- :key: Fetching signing credentials"
bundle exec fastlane ios fetch_signing

# --- Build ---
echo "--- :hammer: Building IPA"
bundle exec fastlane ios build \
  version:"${VERSION}" \
  build_number:"${BUILD_NUMBER}"

# --- Upload ---
echo "--- :rocket: Uploading to TestFlight"
bundle exec fastlane ios upload_testflight

# --- Tag ---
echo "--- :label: Tagging beta build"
git config user.name "buildkite[bot]"
git config user.email "buildkite[bot]@users.noreply.github.com"
TAG="v${VERSION}-beta.${BUILD_NUMBER}"
git tag "${TAG}"
git push origin "${TAG}"

buildkite-agent annotate "Uploaded v${VERSION} (${BUILD_NUMBER}) to TestFlight" \
  --style success --context beta-result
