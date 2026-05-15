#!/usr/bin/env bash
# Run a single test with random bit/real-git routing for intercepted subcommands.
# Env: SHIM_RANDOM_RATIO (default 50)
# Usage: SHIM_RANDOM_RATIO=70 tools/git-t-one-random.sh t3200-branch.sh
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <test_file>" >&2
  exit 1
fi
test_file="$1"

source tools/lib-git-shim.sh

git_shim_setup_env
export SHIM_CMDS="$GIT_SHIM_RANDOM_CMDS"
export SHIM_RANDOM_MODE=1
export SHIM_RANDOM_RATIO="${SHIM_RANDOM_RATIO:-50}"

tools/run-git-test.sh T="$test_file"
