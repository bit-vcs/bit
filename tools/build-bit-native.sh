#!/usr/bin/env bash
# Build the native bit binary and stage a copy for the git-shim harness.
set -euo pipefail

moon build --target native --release

bin_path="_build/native/release/build/mizchi/bit/cmd/bit/bit.exe"
if [ ! -x "$bin_path" ]; then
  echo "bit binary not found at $bin_path" >&2
  exit 1
fi

mkdir -p tools/git-shim
cp "$bin_path" tools/git-shim/moon
chmod +x tools/git-shim/moon
