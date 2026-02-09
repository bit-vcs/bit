#!/bin/bash
#
# e2e: hub command basics (PR/Issue lifecycle)

source "$(dirname "$0")/test-lib-e2e.sh"

test_expect_success 'hub help shows usage' '
    git_cmd hub | grep -q "Usage: bit hub <subcommand>"
'

test_expect_success 'hub issue lifecycle: create close reopen' '
    git_cmd init &&
    git_cmd hub init >/dev/null &&
    issue_out=$(git_cmd hub issue create --title "Hub issue" --body "Body") &&
    issue_id=$(printf "%s\n" "$issue_out" | head -n1 | cut -d" " -f2) &&
    test -n "$issue_id" &&
    git_cmd hub issue list --open | grep -q "Hub issue" &&
    git_cmd hub issue close "$issue_id" >/dev/null &&
    git_cmd hub issue list --closed | grep -q "Hub issue" &&
    git_cmd hub issue reopen "$issue_id" >/dev/null &&
    git_cmd hub issue list --open | grep -q "Hub issue"
'

test_expect_success 'hub pr lifecycle: create close reopen status' '
    git_cmd init &&
    echo "base" > README.md &&
    git_cmd add README.md &&
    git_cmd commit -m "base" &&
    git_cmd checkout -b feature/hub &&
    echo "feature" > feature.txt &&
    git_cmd add feature.txt &&
    git_cmd commit -m "feature" &&
    git_cmd hub init >/dev/null &&
    pr_out=$(git_cmd hub pr create --title "Hub PR" --body "Body" --head refs/heads/feature/hub --base refs/heads/main) &&
    pr_id=$(printf "%s\n" "$pr_out" | head -n1 | cut -d" " -f2) &&
    test -n "$pr_id" &&
    git_cmd hub pr list --open | grep -q "Hub PR" &&
    git_cmd hub pr close "$pr_id" >/dev/null &&
    git_cmd hub pr list --closed | grep -q "Hub PR" &&
    git_cmd hub pr reopen "$pr_id" >/dev/null &&
    git_cmd hub pr list --open | grep -q "Hub PR" &&
    git_cmd hub pr status | grep -q "Current branch: feature/hub" &&
    git_cmd hub pr status | grep -q "Hub PR"
'

test_expect_success 'pr/issue shortcuts continue to work with hub surface' '
    git_cmd init &&
    git_cmd hub init >/dev/null &&
    git_cmd issue list | grep -q "No issues" &&
    git_cmd pr list | grep -q "No pull requests"
'

test_done
