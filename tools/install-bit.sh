#!/usr/bin/env bash
# Install bit to ~/.moon/bin and codesign on macOS.
set -euo pipefail

moon install ./src/cmd/bit

if command -v codesign >/dev/null 2>&1; then
  codesign -fs - ~/.moon/bin/bit
fi
