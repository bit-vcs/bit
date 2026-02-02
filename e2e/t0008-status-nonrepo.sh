#!/bin/bash
#
# Regression tests for status outside repo

source "$(dirname "$0")/test-lib.sh"

test_expect_success 'status in non-repo shows friendly error' '
    mkdir outside &&
    (cd outside &&
        out=$(git_cmd status 2>&1 || true) &&
        echo "$out" | grep -q "Not a git repository" &&
        ! echo "$out" | grep -q "IoError"
    )
'

test_done
