#!/bin/bash
#
# Regression tests for hq get failure exit codes

source "$(dirname "$0")/test-lib-e2e.sh"

test_expect_success 'hq get: invalid repository exits non-zero' '
    test_must_fail git_cmd hq get invalid
'

test_expect_success 'hq get: clone failure exits non-zero' '
    GIT_TERMINAL_PROMPT=0 \
    test_must_fail git_cmd hq get example.invalid/foo/bar
'

test_done
