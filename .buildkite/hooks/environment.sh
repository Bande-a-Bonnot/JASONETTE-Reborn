#!/bin/bash
set -euo pipefail

# Runs on the host agent BEFORE the GetMac VM starts.
# The GetMac plugin forwards exported env vars into the VM via SSH.

# Apple signing credentials
export APP_STORE_CONNECT_API_KEY_KEY_ID=$(buildkite-agent secret get APP_STORE_CONNECT_API_KEY_KEY_ID)
export APP_STORE_CONNECT_API_KEY_ISSUER_ID=$(buildkite-agent secret get APP_STORE_CONNECT_API_KEY_ISSUER_ID)
export APP_STORE_CONNECT_API_KEY_KEY=$(buildkite-agent secret get APP_STORE_CONNECT_API_KEY_KEY)
export APP_STORE_CONNECT_API_KEY_IS_KEY_CONTENT_BASE64="true"
export APPLE_DISTRIBUTION_CERTIFICATE_P12=$(buildkite-agent secret get APPLE_DISTRIBUTION_CERTIFICATE_P12)
export APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD=$(buildkite-agent secret get APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD)

# GetMac project
export GETMAC_PROJECT_ID=$(buildkite-agent secret get GETMAC_PROJECT_ID 2>/dev/null || echo "")

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
