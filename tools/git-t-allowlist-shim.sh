#!/usr/bin/env bash
# Allowlist run via git-shim, defaulting to system git fallback for unintercepted commands.
set -euo pipefail

source tools/lib-git-shim.sh

git_shim_setup_env
export SHIM_CMDS="receive-pack"

tools/run-git-test.sh T="$(git_shim_allowlist_tests)"
