#!/bin/bash
set -e

apt-get update -qq && apt-get install -y -qq git curl build-essential gettext libcurl4-openssl-dev zlib1g-dev >/dev/null 2>&1

curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash 2>/dev/null
export PATH="$HOME/.moon/bin:$PATH"

cd /workspace
moon update 2>/dev/null
moon build --target native --release 2>&1 | tail -1

cp _build/native/release/build/cmd/bit/bit.exe tools/git-shim/moon
chmod +x tools/git-shim/moon

cd third_party/git
make -j$(nproc) 2>/dev/null
cd ../..

real_git="$(pwd)/third_party/git/git"
exec_path="$(pwd)/third_party/git"
shim_dir="$(pwd)/tools/git-shim/bin"

export GIT_TEST_INSTALLED="$shim_dir"
export SHIM_MOON="$(pwd)/tools/git-shim/moon"
export SHIM_REAL_GIT="$real_git"
export SHIM_EXEC_PATH="$exec_path"
export GIT_TEST_EXEC_PATH="$exec_path"
export GIT_TEST_DEFAULT_HASH=sha1
export SHIM_STRICT=1
export SHIM_CMDS="init add diff diff-files diff-index ls-files tag branch checkout switch commit log show reflog reset update-ref update-index status merge rebase clone push fetch pull mv notes stash rm submodule worktree config show-ref for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object ls-tree write-tree commit-tree receive-pack upload-pack pack-objects index-pack format-patch describe gc clean sparse-checkout restore blame grep shell rev-list bisect diff-tree read-tree"

cd third_party/git/t

for t in t0000-basic.sh t0001-init.sh t6101-rev-parse-parents.sh t6302-for-each-ref-filter.sh t3200-branch.sh t1450-fsck.sh; do
  total=$(timeout 120 bash ./$t 2>&1 | grep -c "^ok\|^not ok")
  fail=$(timeout 120 bash ./$t 2>&1 | grep -c "^not ok")
  echo "$t: pass=$((total-fail))/$total fail=$fail"
done
