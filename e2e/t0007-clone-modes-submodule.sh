#!/bin/bash
#
# Regression tests for clone modes and submodule update

source "$(dirname "$0")/test-lib.sh"

test_expect_success 'clone preserves symlink and exec modes' '
    mkdir src &&
    (cd src &&
        git init -q &&
        echo "hello" > target &&
        ln -s target link &&
        echo "#!/bin/sh\necho ok" > script.sh &&
        chmod +x script.sh &&
        git add target link script.sh &&
        git commit -m "init" >/dev/null
    ) &&
    git_cmd clone src dest &&
    git_cmd -C dest status | grep -q "working tree clean" &&
    test -L dest/link &&
    test -x dest/script.sh &&
    diff_out=$(git_cmd -C dest diff --name-only) &&
    test -z "$diff_out" &&
    diff_out=$(git -C dest diff --name-only) &&
    test -z "$diff_out"
'

test_expect_success 'submodule update does not break git diff' '
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
    diff_out=$(git -C clone diff 2>&1) &&
    echo "$diff_out" | grep -q "fatal: this operation must be run in a work tree" && false || true
'

test_done
