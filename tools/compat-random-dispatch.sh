#!/usr/bin/env bash
# Trigger the Git Compat Randomized workflow via workflow_dispatch.
# Usage: tools/compat-random-dispatch.sh [shards] [ratio] [target_shard] [seed]
set -euo pipefail

shards="${1:-1}"
ratio="${2:-50}"
target_shard="${3:-0}"
seed="${4:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required: https://cli.github.com/" >&2
  exit 1
fi

gh workflow run .github/workflows/git-compat-random.yml \
  -f shards="$shards" \
  -f ratio="$ratio" \
  -f target_shard="$target_shard" \
  -f seed="$seed"
