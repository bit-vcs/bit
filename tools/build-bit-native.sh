#!/usr/bin/env bash
# Build the native bit binary and stage a copy for the git-shim harness.
set -euo pipefail

# The new native backend currently ICEs while assembling the full CLI on arm64.
# Match release CI by using the classic backend with a system C compiler.
unset MOONBIT_NEW_NATIVE
if [[ -z "${MOON_CC:-}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    export MOON_CC=/usr/bin/clang
  else
    export MOON_CC=gcc
  fi
fi

moon build --target native --release

bin_path="_build/native/release/build/mizchi/bit/cmd/bit/bit.exe"
if [ ! -x "$bin_path" ]; then
  echo "bit binary not found at $bin_path" >&2
  exit 1
fi

mkdir -p tools/git-shim
cp "$bin_path" tools/git-shim/moon
chmod +x tools/git-shim/moon
