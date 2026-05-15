#!/usr/bin/env bash
# Allowlist run with random bit/real-git routing.
# Env: SHIM_RANDOM_RATIO (default 50)
set -euo pipefail

source tools/lib-git-shim.sh

git_shim_setup_env
export SHIM_CMDS="$GIT_SHIM_RANDOM_CMDS"
export SHIM_RANDOM_MODE=1
export SHIM_RANDOM_RATIO="${SHIM_RANDOM_RATIO:-50}"

tools/run-git-test.sh T="$(git_shim_allowlist_tests)"
