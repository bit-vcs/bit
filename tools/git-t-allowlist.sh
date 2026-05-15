#!/usr/bin/env bash
# Run tests from tools/git-test-allowlist.txt using real git only.
set -euo pipefail

source tools/lib-git-shim.sh

prefix=$(brew --prefix gettext)
CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
  tools/run-git-test.sh T="$(git_shim_allowlist_tests)"
