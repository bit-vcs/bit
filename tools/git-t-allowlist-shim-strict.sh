#!/usr/bin/env bash
# Allowlist run with strict shim — every listed subcommand must go through bit.
set -euo pipefail

source tools/lib-git-shim.sh

git_shim_setup_env
export SHIM_CMDS="$GIT_SHIM_STRICT_CMDS_ALL"
export SHIM_STRICT=1

tools/run-git-test.sh T="$(git_shim_allowlist_tests)"
