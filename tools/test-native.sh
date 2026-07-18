#!/usr/bin/env bash
set -euo pipefail

# cmd/bit's full whitebox suite exceeds the new backend's layout limit. Use
# the classic backend with the system C compiler, matching the sharded CI job.
unset MOONBIT_NEW_NATIVE
if [[ "$(uname -s)" == "Darwin" ]]; then
  # Keep the linker target aligned with the SDK used to compile MoonBit C stubs.
  export MACOSX_DEPLOYMENT_TARGET="$(xcrun --sdk macosx --show-sdk-platform-version)"
fi
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

if [[ "$(uname -s)" == "Darwin" ]]; then
  # moonc currently ICEs while linking cmd/bit's native whitebox driver on
  # arm64 macOS. The six shards run in Linux CI; the native release build and
  # all non-CLI native package tests above still run locally.
  echo "[native] skipping cmd/bit whitebox shards on Darwin (moonc layout ICE)"
else
  for shard in 0 1 2 3 4 5; do
    # shellcheck disable=SC2012
    files=$(ls modules/bit/cmd/bit/*.mbt | sort | awk "(NR-1) % 6 == $shard")
    echo "[native] cmd/bit shard $shard/6"
    # Moon expects the selected files as separate positional arguments.
    # shellcheck disable=SC2086
    moon test --target native --no-parallelize $files
  done
fi
