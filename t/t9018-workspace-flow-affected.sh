#!/bin/sh
#
# Test workspace flow --affected execution scope and cache reuse
#

test_description='workspace flow --affected runs only impacted nodes and reuses cache'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

test_expect_success 'setup: create workspace root and nested repositories' '
	mkdir flow-logs &&
	mkdir ws &&
	(cd ws &&
	 git init &&
	 git config user.email "test@example.com" &&
	 git config user.name "Test User" &&
	 echo "root-v1" > root.txt &&
	 git add root.txt &&
	 git commit -m "root init") &&
	mkdir ws/dep ws/leaf ws/extra &&
	(cd ws/dep &&
	 git init &&
	 git config user.email "test@example.com" &&
	 git config user.name "Test User" &&
	 echo "dep-v1" > dep.txt &&
	 git add dep.txt &&
	 git commit -m "dep init") &&
	(cd ws/leaf &&
	 git init &&
	 git config user.email "test@example.com" &&
	 git config user.name "Test User" &&
	 echo "leaf-v1" > leaf.txt &&
	 git add leaf.txt &&
	 git commit -m "leaf init") &&
	(cd ws/extra &&
	 git init &&
	 git config user.email "test@example.com" &&
	 git config user.name "Test User" &&
	 echo "extra-v1" > extra.txt &&
	 git add extra.txt &&
	 git commit -m "extra init")
'

test_expect_success 'setup: initialize workspace manifest with dependency edges' '
	(cd ws &&
	 $BIT workspace init --template flow >../ws-flow-affected-init.out 2>&1 &&
	 test -f .git/workspace.toml &&
	 test -f .git/workspace.lock.json)
'

test_expect_success 'workspace flow baseline generates cache entries for all nodes' '
	(cd ws &&
	 BIT_WORKSPACE_FLOW_LOG_DIR="$PWD/../flow-logs" $BIT workspace flow test >../ws-flow-affected-baseline.out 2>&1) &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 1 &&
	test_line_count = flow-logs/leaf.log 1 &&
	test_line_count = flow-logs/extra.log 1 &&
	test_path_is_file ws/.git/workspace.flow-cache.json &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-affected-baseline.out | head -n 1 > ws-flow-affected-baseline-txn.txt &&
	test -s ws-flow-affected-baseline-txn.txt
'

test_expect_success 'workspace flow --affected executes impacted graph and skips unrelated node' '
	echo "dep-v2" >> ws/dep/dep.txt &&
	(cd ws &&
	 BIT_WORKSPACE_FLOW_LOG_DIR="$PWD/../flow-logs" $BIT workspace flow test --affected >../ws-flow-affected-first.out 2>&1) &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 2 &&
	test_line_count = flow-logs/leaf.log 2 &&
	test_line_count = flow-logs/extra.log 1 &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-affected-first.out | head -n 1 > ws-flow-affected-first-txn.txt &&
	test -s ws-flow-affected-first-txn.txt &&
	grep -q "\"node_id\": \"root\"" ws/.git/txns/$(cat ws-flow-affected-first-txn.txt).json &&
	grep -q "\"node_id\": \"dep\"" ws/.git/txns/$(cat ws-flow-affected-first-txn.txt).json &&
	grep -q "\"node_id\": \"leaf\"" ws/.git/txns/$(cat ws-flow-affected-first-txn.txt).json &&
	! grep -q "\"node_id\": \"extra\"" ws/.git/txns/$(cat ws-flow-affected-first-txn.txt).json
'

test_expect_success 'workspace flow --affected reuses cache for same impacted graph' '
	(cd ws &&
	 BIT_WORKSPACE_FLOW_LOG_DIR="$PWD/../flow-logs" $BIT workspace flow test --affected >../ws-flow-affected-second.out 2>&1) &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 2 &&
	test_line_count = flow-logs/leaf.log 2 &&
	test_line_count = flow-logs/extra.log 1 &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-affected-second.out | head -n 1 > ws-flow-affected-second-txn.txt &&
	test -s ws-flow-affected-second-txn.txt &&
	grep -q "\"status\": \"cached\"" ws/.git/txns/$(cat ws-flow-affected-second-txn.txt).json
'

test_done
