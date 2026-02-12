#!/bin/sh
#
# Test workspace flow task metadata support (cmd/srcs/outs/env/cwd/trigger_mode)
#

test_description='workspace flow honors extended task metadata and cache planning'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

FIXTURE_DIR="$BIT_BUILD_DIR/fixtures/workspace_flow"

test_expect_success 'setup: bootstrap workspace repositories and metadata manifest' '
	"$FIXTURE_DIR/bootstrap.sh" ws &&
	mkdir flow-logs &&
	mkdir -p ws/dep/subdir &&
	(cd ws &&
	 $BIT workspace init >/dev/null &&
	 cat > .git/workspace.toml <<-\EOF
	version = 1

	[[nodes]]
	id = "root"
	path = "."
	required = true
depends_on = []
task.test.cmd = "echo \"$FLOW_MARK\" >> \"$FLOW_OUT_DIR/root.log\""
task.test.srcs = ["root.txt"]
task.test.outs = ["root.log"]
task.test.env.FLOW_MARK = "root-v1"
task.test.env.FLOW_OUT_DIR = "../flow-logs"

	[[nodes]]
	id = "dep"
	path = "dep"
	required = true
depends_on = ["root"]
task.test.cmd = "echo \"$FLOW_MARK\" >> \"$FLOW_OUT_DIR/dep.log\""
task.test.cwd = "subdir"
task.test.trigger_mode = "auto"
task.test.srcs = ["dep.txt"]
task.test.outs = ["subdir/dep.log"]
task.test.env.FLOW_MARK = "dep-v1"
task.test.env.FLOW_OUT_DIR = "../../../flow-logs"
	EOF
	)
'

test_expect_success 'workspace flow writes files using env and cwd metadata' '
	(cd ws &&
	 $BIT workspace flow test >../ws-flow-meta-first.out 2>&1) &&
	test_path_is_file flow-logs/root.log &&
	test_path_is_file flow-logs/dep.log &&
	test_path_is_missing ws/root.log &&
	test_path_is_missing ws/dep/subdir/dep.log &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 1 &&
	grep "root-v1" flow-logs/root.log &&
	grep "dep-v1" flow-logs/dep.log
'

test_expect_success 'workspace flow cache reuses previous task fingerprints' '
	(cd ws &&
	 $BIT workspace flow test >../ws-flow-meta-second.out 2>&1) &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 1 &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-meta-second.out | head -n 1 > ws-flow-meta-second-txn.txt &&
	test -s ws-flow-meta-second-txn.txt &&
	grep "\"status\": \"cached\"" ws/.git/txns/$(cat ws-flow-meta-second-txn.txt).json
'

test_expect_success 'changing task metadata invalidates only affected task cache entry' '
	perl -0pi -e "s/dep-v1/dep-v2/g" ws/.git/workspace.toml &&
	(cd ws &&
	 $BIT workspace flow test >../ws-flow-meta-third.out 2>&1) &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 2 &&
	grep "dep-v2" flow-logs/dep.log &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-meta-third.out | head -n 1 > ws-flow-meta-third-txn.txt &&
	test -s ws-flow-meta-third-txn.txt &&
	grep "\"node_id\": \"root\"" ws/.git/txns/$(cat ws-flow-meta-third-txn.txt).json &&
	grep "\"status\": \"cached\"" ws/.git/txns/$(cat ws-flow-meta-third-txn.txt).json &&
	grep "\"node_id\": \"dep\"" ws/.git/txns/$(cat ws-flow-meta-third-txn.txt).json &&
	grep "\"status\": \"success\"" ws/.git/txns/$(cat ws-flow-meta-third-txn.txt).json
'

test_done
