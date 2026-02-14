#!/bin/bash
#
# Test --no-git-fallback behavior

source "$(dirname "$0")/test-lib-e2e.sh"

test_expect_failure 'unsupported command fails with --no-git-fallback' '
    git_cmd init &&
    git_cmd blame README.md
'

test_expect_success 'version command works with --no-git-fallback' '
    git_cmd --version | grep -q "git version"
'

test_expect_success 'help command works with --no-git-fallback' '
    git_cmd --help | grep -q "bit is a Git implementation"
'

test_expect_success 'config works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        SHIM_REAL_GIT=/no/such git_cmd config user.name "bit-test" &&
        test "$(git_cmd config --get user.name)" = "bit-test"
    )
'

test_expect_success 'update-ref works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        echo hello >a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "first commit" &&
        head_oid="$(git_cmd rev-parse HEAD)" &&
        SHIM_REAL_GIT=/no/such git_cmd update-ref refs/heads/smoke "$head_oid" &&
        test "$(git_cmd rev-parse refs/heads/smoke)" = "$head_oid"
    )
'

test_expect_success 'branch works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        echo hello >a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "first commit" &&
        head_oid="$(git_cmd rev-parse HEAD)" &&
        SHIM_REAL_GIT=/no/such git_cmd branch smoke "$head_oid" &&
        test "$(git_cmd rev-parse refs/heads/smoke)" = "$head_oid"
    )
'

test_expect_success 'log works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        echo hello >a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "first commit" &&
        SHIM_REAL_GIT=/no/such git_cmd log --oneline -1 >actual &&
        grep -Eq "^[0-9a-f]{7} " actual
    )
'

test_expect_success 'log -1 works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        echo hello >a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "first commit" &&
        SHIM_REAL_GIT=/no/such git_cmd log -1 >actual &&
        grep -q "^commit [0-9a-f]\\{40\\}$" actual
    )
'

test_expect_success 'checkout works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        echo hello >a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "first commit" &&
        git_cmd branch smoke &&
        SHIM_REAL_GIT=/no/such git_cmd checkout smoke &&
        git_cmd branch | grep -q "\\* smoke"
    )
'

test_expect_success 'merge works even if SHIM_REAL_GIT is invalid' '
    git_cmd init repo &&
    (
        cd repo &&
        git_cmd config user.name "bit-test" &&
        git_cmd config user.email "bit-test@example.com" &&
        echo base >a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "base commit" &&
        base_branch="$(git_cmd rev-parse --abbrev-ref HEAD)" &&
        git_cmd checkout -b feature &&
        echo feature >>a.txt &&
        git_cmd add a.txt &&
        git_cmd commit -m "feature commit" &&
        git_cmd checkout "$base_branch" &&
        SHIM_REAL_GIT=/no/such git_cmd merge feature &&
        test "$(git_cmd rev-parse HEAD)" = "$(git_cmd rev-parse feature)"
    )
'

test_done
