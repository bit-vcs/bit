#!/usr/bin/env bash
# Focused local git-compat sampling via flaker.
# Usage: tools/flaker-git-compat-sample.sh [strategy] [count] [changed]
set -euo pipefail

strategy="${1:-weighted}"
count="${2:-25}"
changed="${3:-}"

if { [ "$strategy" = "affected" ] || [ "$strategy" = "hybrid" ]; } && [ -z "$changed" ]; then
  echo "changed=... is required when strategy=$strategy" >&2
  exit 1
fi

args=(sample --strategy "$strategy" --count "$count")
if [ -n "$changed" ]; then
  args+=(--changed "$changed")
fi

node tools/flaker-cli-wrapper.mjs "${args[@]}"
