#!/bin/bash
#
# Test local clone operations
# All tests use git_cmd (--no-git-fallback), no real git required.
# Source repos are also created with git_cmd for full standalone.

source "$(dirname "$0")/test-lib-e2e.sh"

# Helper: create a source repo with a couple of commits
make_source_repo() {
    git_cmd init source &&
    (cd source &&
        echo "file1" > file1.txt &&
        git_cmd add file1.txt &&
        git_cmd commit -m "first commit" &&
        echo "file2" > file2.txt &&
        git_cmd add file2.txt &&
        git_cmd commit -m "second commit"
    )
}

# =============================================================================
# Basic clone (4)
# =============================================================================

test_expect_success 'clone local repo creates working copy' '
    make_source_repo &&
    git_cmd clone source dest &&
    test_dir_exists dest/.git &&
    test_file_exists dest/file1.txt &&
    test_file_exists dest/file2.txt
'

test_expect_success 'clone sets up origin remote config' '
    make_source_repo &&
    git_cmd clone source dest &&
    git_cmd -C dest remote -v > out &&
    grep -q "origin" out
'

test_expect_success 'clone checkout matches source HEAD content' '
    make_source_repo &&
    git_cmd clone source dest &&
    diff source/file1.txt dest/file1.txt &&
    diff source/file2.txt dest/file2.txt
'

test_expect_success 'clone --bare creates bare repository' '
    make_source_repo &&
    git_cmd clone --bare source dest.git &&
    test_file_exists dest.git/HEAD &&
    test_dir_exists dest.git/objects &&
    test_dir_exists dest.git/refs &&
    test_path_is_missing dest.git/file1.txt
'

# =============================================================================
# History and branches (3)
# =============================================================================

test_expect_success 'clone preserves commit history' '
    make_source_repo &&
    git_cmd clone source dest &&
    src_count=$(git_cmd -C source log --oneline | wc -l | tr -d " ") &&
    dst_count=$(git_cmd -C dest log --oneline | wc -l | tr -d " ") &&
    test "$src_count" = "$dst_count"
'

test_expect_success 'clone preserves multiple branches in packed-refs' '
    make_source_repo &&
    (cd source && git_cmd branch feature) &&
    git_cmd clone source dest &&
    grep -q "refs/remotes/origin/feature" dest/.git/packed-refs
'

test_skip 'clone with -b checks out specified branch' 'clone -b not yet supported'

# =============================================================================
# Directory creation (3)
# =============================================================================

test_expect_success 'clone creates new directory automatically' '
    make_source_repo &&
    test_path_is_missing mydir &&
    git_cmd clone source mydir &&
    test_dir_exists mydir/.git
'

test_expect_success 'clone deep path (a/b/c)' '
    make_source_repo &&
    test_path_is_missing a &&
    git_cmd clone source a/b/c &&
    test_dir_exists a/b/c/.git &&
    test_file_exists a/b/c/file1.txt
'

test_expect_success 'clone local bare repo as source' '
    make_source_repo &&
    git_cmd clone --bare source bare.git &&
    git_cmd clone bare.git dest &&
    test_file_exists dest/file1.txt &&
    test_file_exists dest/file2.txt
'

# =============================================================================
# Edge cases (2)
# =============================================================================

test_expect_success 'clone detached HEAD source' '
    make_source_repo &&
    (cd source &&
        first_hash=$(git_cmd rev-parse HEAD~1) &&
        git_cmd checkout "$first_hash"
    ) &&
    git_cmd clone source dest &&
    test_file_exists dest/file1.txt
'

test_skip 'clone empty repo (no commits yet)' 'empty repo clone not yet supported'

test_done
