#!/bin/sh
#
# Test workspace flow starlark workflow file support
#

test_description='workspace flow can execute .star workflows with cache'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

FIXTURE_DIR="$BIT_BUILD_DIR/fixtures/workspace_flow"

test_expect_success "setup: bootstrap workspace and write bitflow.star" '
	"$FIXTURE_DIR/bootstrap.sh" ws &&
	mkdir -p ws/dep/subdir &&
	mkdir flow-logs &&
	(cd ws &&
	 $BIT workspace init >/dev/null &&
	 cat > bitflow.star <<-\EOF
	workflow(name="ws", max_parallel=1)
	node(id="root", depends_on=[])
	node(id="dep", depends_on=["root"])
	task(
	  id="root:test",
	  node="root",
	  cmd="echo \"$FLOW_MARK\" >> \"$FLOW_OUT_DIR/root.log\"",
	  needs=[],
	  env={"FLOW_MARK": "root-v1", "FLOW_OUT_DIR": "../flow-logs"},
	  srcs=["root.txt"],
	  outs=["../flow-logs/root.log"],
	  trigger="auto",
	)
	task(
	  id="dep:test",
	  node="dep",
	  cmd="echo \"$FLOW_MARK\" >> \"$FLOW_OUT_DIR/dep.log\"",
	  needs=["root:test"],
	  cwd="dep/subdir",
	  env={"FLOW_MARK": "dep-v1", "FLOW_OUT_DIR": "../../../flow-logs"},
	  srcs=["dep/dep.txt"],
	  outs=["../../../flow-logs/dep.log"],
	  trigger="auto",
	)
	entrypoint(targets=["dep:test"])
	EOF
	)
'

test_expect_success "workspace flow executes bitflow.star tasks without --star" '
	(cd ws &&
	 $BIT workspace flow --target dep:test >../ws-flow-star-first.out 2>&1) &&
	test_path_is_file flow-logs/root.log &&
	test_path_is_file flow-logs/dep.log &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 1 &&
	grep "root-v1" flow-logs/root.log &&
	grep "dep-v1" flow-logs/dep.log
'

test_expect_success 'workspace flow reuses cache for unchanged .star workflow' '
	(cd ws &&
	 $BIT workspace flow --target dep:test >../ws-flow-star-second.out 2>&1) &&
	test_line_count = flow-logs/root.log 1 &&
	test_line_count = flow-logs/dep.log 1 &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-star-second.out | head -n 1 > ws-flow-star-second-txn.txt &&
	test -s ws-flow-star-second-txn.txt &&
	grep "\"status\": \"cached\"" ws/.git/txns/$(cat ws-flow-star-second-txn.txt).json
'

test_expect_success 'workspace flow invalidates affected task when .star metadata changes' '
	perl -0pi -e "s/dep-v1/dep-v2/g" ws/bitflow.star &&
	(cd ws &&
	 $BIT workspace flow --target dep:test >../ws-flow-star-third.out 2>&1) &&
	test_line_count = flow-logs/root.log 2 &&
	test_line_count = flow-logs/dep.log 2 &&
	grep "dep-v2" flow-logs/dep.log &&
	sed -n "s/.*workspace flow txn: \\([^ ]*\\).*/\\1/p" ws-flow-star-third.out | head -n 1 > ws-flow-star-third-txn.txt &&
	test -s ws-flow-star-third-txn.txt &&
	grep "\"node_id\": \"root\"" ws/.git/txns/$(cat ws-flow-star-third-txn.txt).json &&
	grep "\"status\": \"success\"" ws/.git/txns/$(cat ws-flow-star-third-txn.txt).json &&
	grep "\"node_id\": \"dep\"" ws/.git/txns/$(cat ws-flow-star-third-txn.txt).json &&
	grep "\"status\": \"success\"" ws/.git/txns/$(cat ws-flow-star-third-txn.txt).json
'

test_expect_success "workspace flow --config defaults to bitflow.star when value omitted" '
	(cd ws &&
	 $BIT workspace flow --config --target dep:test --no-cache >../ws-flow-star-fourth.out 2>&1) &&
	! grep "unsupported option '\''--config'\''" ws-flow-star-fourth.out &&
	test_line_count = flow-logs/root.log 3 &&
	test_line_count = flow-logs/dep.log 3
'

test_expect_success "workspace flow -c accepts explicit config path" '
	(cd ws &&
	 $BIT workspace flow -c ./bitflow.star --target dep:test --no-cache >../ws-flow-star-fifth.out 2>&1) &&
	! grep "unsupported option '\''-c'\''" ws-flow-star-fifth.out &&
	test_line_count = flow-logs/root.log 4 &&
	test_line_count = flow-logs/dep.log 4
'

test_expect_success "workspace flow rejects removed --star option" '
	(cd ws &&
	 if $BIT workspace flow --star --target dep:test >../ws-flow-star-removed.out 2>&1; then
	   false
	 else
	   true
	 fi) &&
	grep "workspace flow: --star is removed; use --config or -c" ws-flow-star-removed.out
'

test_done
