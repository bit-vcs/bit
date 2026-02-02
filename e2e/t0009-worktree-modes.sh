#!/bin/bash
#
# Regression tests for worktree mode/symlink changes

source "$(dirname "$0")/test-lib.sh"

test_expect_success 'status/diff detect exec bit and symlink changes' '
    git_cmd init >/dev/null &&
    printf "#!/bin/sh\necho hi\n" > run.sh &&
    chmod +x run.sh &&
    printf "a\n" > a.txt &&
    ln -s a.txt link.txt &&
    git_cmd add run.sh a.txt link.txt &&
    git_cmd commit -m "init" >/dev/null &&
    chmod -x run.sh &&
    rm link.txt &&
    ln -s run.sh link.txt &&
    out=$(git_cmd status) &&
    echo "$out" | grep -q "modified: run.sh" &&
    echo "$out" | grep -q "modified: link.txt" &&
    diff_out=$(git_cmd diff) &&
    echo "$diff_out" | grep -q "diff --git a/run.sh b/run.sh" &&
    echo "$diff_out" | grep -q "old mode 100755" &&
    echo "$diff_out" | grep -q "new mode 100644" &&
    echo "$diff_out" | grep -q "diff --git a/link.txt b/link.txt" &&
    echo "$diff_out" | grep -q -- "^-a.txt" &&
    echo "$diff_out" | grep -q -- "^+run.sh"
'

test_done
