#!/bin/sh
#
# Test workspace flow reporting integration with hub PR workflow records
#

test_description='workspace flow can report workflow status to hub PR'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

FIXTURE_DIR="$BIT_BUILD_DIR/fixtures/workspace_flow"

test_expect_success 'setup: bootstrap workspace, init hub, and create PR' '
	"$FIXTURE_DIR/bootstrap.sh" ws &&
	(cd ws &&
	 $BIT workspace init >/dev/null &&
	 cp "$FIXTURE_DIR/workspace.toml" .git/workspace.toml &&
	 $BIT hub init >/dev/null &&
	 git checkout -b feature/ws-flow-hub >/dev/null &&
	 echo "workspace hub flow" > ws-hub-flow.txt &&
	 git add ws-hub-flow.txt &&
	 git commit -m "workspace hub flow" >/dev/null &&
	 git checkout main >/dev/null &&
	 pr_out=$($BIT hub pr create --title "Workspace Flow PR" --body "Body" --head refs/heads/feature/ws-flow-hub --base refs/heads/main) &&
	 pr_id=$(printf "%s\n" "$pr_out" | head -n1 | cut -d" " -f2) &&
	 test -n "$pr_id" &&
	 printf "%s\n" "$pr_id" > ../ws-flow-pr-id.txt
	)
'

test_expect_success 'workspace flow --pr records workflow result with fingerprint' '
	mkdir flow-logs &&
	pr_id=$(cat ws-flow-pr-id.txt) &&
	(cd ws &&
	 BIT_WORKSPACE_FLOW_LOG_DIR="$PWD/../flow-logs" $BIT workspace flow test --pr "$pr_id" > ../ws-flow-hub.out 2>&1 &&
	 workflow_out=$($BIT hub pr workflow list "$pr_id") &&
	 printf "%s\n" "$workflow_out" | grep -q "task=test" &&
	 printf "%s\n" "$workflow_out" | grep -q "status=success" &&
	 printf "%s\n" "$workflow_out" | grep -q "fingerprint=" &&
	 grep -q "workspace flow txn:" ../ws-flow-hub.out &&
	 grep -q "workspace flow report: pr" ../ws-flow-hub.out
	)
'

test_done
