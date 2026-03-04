#!/bin/bash
set +e

# Clean up temporary keychain on self-hosted runner
security delete-keychain fastlane_tmp_keychain 2>/dev/null || true
