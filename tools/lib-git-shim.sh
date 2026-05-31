#!/usr/bin/env bash
# Shared helpers for git-test-shim wrappers.
# Sourced by tools/git-t-*.sh scripts.

set -euo pipefail

tools/apply-git-test-patches.sh

git_shim_setup_env() {
  local prefix
  prefix=$(brew --prefix gettext)

  local real_git="$(pwd)/third_party/git/git"
  local exec_path
  local fallback_real_git=""
  if [ -x "$real_git" ]; then
    exec_path="$(pwd)/third_party/git"
    fallback_real_git="$(/usr/bin/which git)"
    if [ "$fallback_real_git" = "$real_git" ]; then
      fallback_real_git=""
    fi
  else
    real_git=$(/usr/bin/which git)
    exec_path=$($real_git --exec-path)
  fi

  local shim_dir="$(pwd)/tools/git-shim/bin"
  echo "$real_git" > tools/git-shim/real-git-path

  export SHIM_REAL_GIT="$real_git"
  export SHIM_REAL_GIT_FALLBACK="$fallback_real_git"
  export SHIM_EXEC_PATH="$exec_path"
  export SHIM_MOON="$(pwd)/tools/git-shim/moon"
  export GIT_TEST_INSTALLED="$shim_dir"
  export GIT_TEST_EXEC_PATH="$exec_path"
  export GIT_TEST_DEFAULT_HASH=sha1
  export CPATH="$prefix/include"
  export LDFLAGS="-L$prefix/lib"
  export LIBRARY_PATH="$prefix/lib"
}

git_shim_allowlist_tests() {
  rg -v '^[[:space:]]*#' tools/git-test-allowlist.txt \
    | rg -v '^[[:space:]]*$' | tr '\n' ' '
}

# Default shim command lists (used by multiple wrappers).
GIT_SHIM_STRICT_CMDS_ALL="init add diff diff-files diff-index ls-files tag branch checkout switch commit log show reflog reset update-ref update-index status merge rebase clone push fetch pull mv notes stash rm submodule worktree config show-ref for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object ls-tree write-tree commit-tree receive-pack upload-pack pack-objects index-pack format-patch describe gc clean sparse-checkout restore blame grep commit-graph multi-pack-index shell"

GIT_SHIM_RANDOM_CMDS="init status add commit log show branch checkout switch reset rebase stash cherry-pick diff diff-files diff-index merge tag rm mv config sparse-checkout restore rev-parse cat-file ls-files hash-object ls-tree write-tree show-ref update-ref symbolic-ref reflog worktree gc clean grep submodule revert notes bisect describe blame format-patch shortlog remote clone fetch pull push receive-pack upload-pack pack-objects index-pack commit-graph multi-pack-index shell"

GIT_SHIM_FULL_CMDS="init status add commit log show branch checkout switch reset rebase stash cherry-pick diff diff-files diff-index merge tag rm mv config sparse-checkout restore rev-parse cat-file ls-files hash-object ls-tree write-tree show-ref update-ref update-index symbolic-ref reflog worktree gc clean grep submodule revert notes bisect describe blame format-patch shortlog remote clone fetch pull push receive-pack upload-pack pack-objects index-pack commit-graph multi-pack-index shell"

GIT_SHIM_ONE_CMDS="init receive-pack upload-pack pack-objects index-pack shell"
GIT_SHIM_ONE_REMOTE_CMDS="init receive-pack upload-pack pack-objects index-pack remote shell"
