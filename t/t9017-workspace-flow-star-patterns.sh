#!/bin/sh
#
# Test workspace flow bitflow.star advanced patterns
#

test_description='workspace flow supports bitflow.star load, vars, and command list patterns'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

FIXTURE_DIR="$BIT_BUILD_DIR/fixtures/workspace_flow"

test_expect_success 'setup: bootstrap workspace and write modular bitflow.star with load()' '
	"$FIXTURE_DIR/bootstrap.sh" ws &&
	mkdir -p ws/defs ws/flow-logs &&
	(cd ws &&
	 $BIT workspace init >/dev/null &&
	 cat > bitflow.star <<-\EOF
	workflow(name="ws-patterns", max_parallel=1)
	var(name="flow_mark", type="string", required=True)
	node(id="root", depends_on=[])
	task(
	  id="root:test",
	  node="root",
	  cmd=["echo", "$FLOW_MARK", ">>", "$FLOW_OUT_DIR/root.log"],
	  needs=[],
	  env={"FLOW_MARK": flow_mark, "FLOW_OUT_DIR": "flow-logs"},
	  srcs=["root.txt"],
	  outs=["flow-logs/root.log"],
	  trigger="auto",
	)
	load(path="defs/dep.star")
	entrypoint(targets=["dep:test"])
	EOF
	 cat > defs/dep.star <<-\EOF
	node(id="dep", depends_on=["root"])
	task(
	  id="dep:test",
	  node="dep",
	  cmd="echo \"$FLOW_MARK\" >> \"$FLOW_OUT_DIR/dep.log\"",
	  needs=["root:test"],
	  cwd="dep",
	  env={"FLOW_MARK": flow_mark, "FLOW_OUT_DIR": "../flow-logs"},
	  srcs=["dep/dep.txt"],
	  outs=["../flow-logs/dep.log"],
	  trigger="auto",
	)
	EOF
	)
'

test_expect_success 'workspace flow star fails when required var is missing' '
	(cd ws &&
	 if $BIT workspace flow --target dep:test >../ws-flow-star-pattern-missing.out 2>&1; then
	   false
	 else
	   true
	 fi) &&
	grep "unknown variable '\''flow_mark'\''" ws-flow-star-pattern-missing.out
'

test_expect_success 'workspace flow star resolves required var from BITFLOW_VAR_* env' '
	(cd ws &&
	 BITFLOW_VAR_flow_mark=env-v1 $BIT workspace flow --target dep:test >../ws-flow-star-pattern-env.out 2>&1) &&
	test_line_count = ws/flow-logs/root.log 1 &&
	test_line_count = ws/flow-logs/dep.log 1 &&
	grep "env-v1" ws/flow-logs/root.log &&
	grep "env-v1" ws/flow-logs/dep.log
'

test_expect_success 'workspace flow star lets --var override env value' '
	(cd ws &&
	 BITFLOW_VAR_flow_mark=env-v1 $BIT workspace flow --target dep:test --no-cache --var flow_mark=cli-v2 >../ws-flow-star-pattern-cli.out 2>&1) &&
	test_line_count = ws/flow-logs/root.log 2 &&
	test_line_count = ws/flow-logs/dep.log 2 &&
	grep "cli-v2" ws/flow-logs/root.log &&
	grep "cli-v2" ws/flow-logs/dep.log
'

test_expect_success 'workspace flow star rejects undeclared external input key' '
	(cd ws &&
	 if BITFLOW_VAR_flow_mark=env-v1 $BIT workspace flow --target dep:test --var not_declared=value >../ws-flow-star-pattern-unknown.out 2>&1; then
	   false
	 else
	   true
	 fi) &&
	grep "external input '\''not_declared'\'' is not declared by var()" ws-flow-star-pattern-unknown.out
'

test_expect_success 'workspace flow supports positional .star path with --target all' '
	(cd ws &&
	 BITFLOW_VAR_flow_mark=all-v3 $BIT workspace flow ./bitflow.star --target all --no-cache >../ws-flow-star-pattern-all.out 2>&1) &&
	test_line_count = ws/flow-logs/root.log 3 &&
	test_line_count = ws/flow-logs/dep.log 3 &&
	grep "all-v3" ws/flow-logs/root.log &&
	grep "all-v3" ws/flow-logs/dep.log
'

test_done
