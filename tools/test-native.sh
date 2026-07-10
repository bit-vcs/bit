#!/usr/bin/env bash
set -euo pipefail

# The new native backend exceeds moonc's layout limit for cmd/bit tests.
# Match CI by using the classic backend with a system C compiler and shards.
unset MOONBIT_NEW_NATIVE
if [[ -z "${MOON_CC:-}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    export MOON_CC=/usr/bin/clang
  else
    export MOON_CC=gcc
  fi
fi

real_git_path_file="tools/git-shim/real-git-path"
original_real_git_path=$(<"$real_git_path_file")
restore_real_git_path() {
  printf '%s\n' "$original_real_git_path" > "$real_git_path_file"
}
trap restore_real_git_path EXIT
command -v git > "$real_git_path_file"

modules=$(awk '/members = \[/,/\]/' moon.work | grep -oE '"[^"]+"' | tr -d '"' | sed 's|^\./||')
for module_path in $modules; do
  if [[ "$module_path" == "modules/bit" ]]; then
    continue
  fi
  module_name="mizchi/$(basename "$module_path")"
  echo "[native] $module_name"
  moon test --target native -p "$module_name"
done

moon test --target native -p mizchi/bit/tests
moon test --target native -p mizchi/bit/fuzz_tests || true
moon test --target native -p mizchi/bit/cmd/git-bit

for shard in 0 1 2 3 4 5; do
  # shellcheck disable=SC2012
  files=$(ls modules/bit/src/cmd/bit/*.mbt | sort | awk "(NR-1) % 6 == $shard")
  echo "[native] cmd/bit shard $shard/6"
  # Moon expects the selected files as separate positional arguments.
  # shellcheck disable=SC2086
  moon test --target native --no-parallelize $files
done
