#!/usr/bin/env bash
# Focused local git-compat execution via flaker.
# Requires `pkf run build` (or `tools/build-bit-native.sh`) to have been run first
# so the native bit binary is staged for the git-shim harness.
# Usage: tools/flaker-git-compat-run.sh [strategy] [count] [changed]
set -euo pipefail

strategy="${1:-weighted}"
count="${2:-25}"
changed="${3:-}"

if { [ "$strategy" = "affected" ] || [ "$strategy" = "hybrid" ]; } && [ -z "$changed" ]; then
  echo "changed=... is required when strategy=$strategy" >&2
  exit 1
fi

args=(run --strategy "$strategy" --count "$count")
if [ -n "$changed" ]; then
  args+=(--changed "$changed")
fi

node tools/flaker-cli-wrapper.mjs "${args[@]}"
