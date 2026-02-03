#!/bin/bash
#
# Verify repositories modified by bit are still valid for git

source "$(dirname "$0")/test-lib.sh"

test_expect_success 'git fsck passes after merge and reset' '
    git_cmd init &&
    echo "base" > a.txt &&
    git_cmd add a.txt &&
    git_cmd commit -m "c1" &&
    git_cmd checkout -b feature &&
    echo "feature" > feature.txt &&
    git_cmd add feature.txt &&
    git_cmd commit -m "c2" &&
    if ! git_cmd checkout main; then git_cmd checkout master; fi &&
    echo "main" > main.txt &&
    git_cmd add main.txt &&
    git_cmd commit -m "c3" &&
    git_cmd merge feature -m "merge feature" &&
    git_cmd reset --hard HEAD~1 &&
    command git fsck --strict &&
    command git status --porcelain=2 >/dev/null
'

test_expect_success 'git fsck passes after rebase' '
    git_cmd init &&
    echo "base" > a.txt &&
    git_cmd add a.txt &&
    git_cmd commit -m "c1" &&
    git_cmd checkout -b feature &&
    echo "feature" > feature.txt &&
    git_cmd add feature.txt &&
    git_cmd commit -m "c2" &&
    if ! git_cmd checkout main; then git_cmd checkout master; fi &&
    echo "main" > main.txt &&
    git_cmd add main.txt &&
    git_cmd commit -m "c3" &&
    git_cmd checkout feature &&
    git_cmd rebase main &&
    command git fsck --strict &&
    command git status --porcelain=2 >/dev/null
'

test_expect_success 'git fsck passes after submodule update' '
    mkdir sub &&
    (cd sub &&
        git init -q &&
        echo "sub" > sub.txt &&
        git add sub.txt &&
        git commit -m "sub" >/dev/null
    ) &&
    mkdir main &&
    (cd main &&
        git init -q &&
        GIT_ALLOW_PROTOCOL=file git -c protocol.file.allow=always submodule add ../sub third_party/sub >/dev/null &&
        git commit -m "add submodule" >/dev/null
    ) &&
    git_cmd clone main clone &&
    (cd clone && git_cmd submodule update --init --recursive) &&
    command git -C clone fsck --strict &&
    command git -C clone/third_party/sub fsck --strict
'

test_expect_success 'git fsck passes after gc and repack' '
    git_cmd init &&
    echo "one" > a.txt &&
    git_cmd add a.txt &&
    git_cmd commit -m "c1" &&
    echo "two" >> a.txt &&
    git_cmd add a.txt &&
    git_cmd commit -m "c2" &&
    git_cmd gc &&
    git_cmd repack -ad &&
    command git fsck --strict &&
    command git status --porcelain=2 >/dev/null
'

test_done
