#!/usr/bin/env bash
# Run a single Git upstream test in strict shim mode.
# Usage: tools/git-t-one.sh t3200-branch.sh
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <test_file>" >&2
  exit 1
fi
test_file="$1"

source tools/lib-git-shim.sh

git_shim_setup_env
export SHIM_CMDS="$GIT_SHIM_ONE_CMDS"
export SHIM_STRICT=1

tools/run-git-test.sh T="$test_file"
