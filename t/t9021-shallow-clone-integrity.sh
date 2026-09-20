#!/bin/sh
#
# Shallow clones must record the boundary the server reported, and every
# history walk must stop there instead of running into objects that were
# never fetched.
#

test_description='bit shallow clone records its boundary and keeps history intact'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

if ! test_have_prereq GIT; then
	test_skip "shallow clone integrity" "git not found"
	test_done
fi

# `bit` is run with --no-git-fallback throughout: without it clone and gc are
# delegated to the real git binary and none of this exercises bit at all.
bit_cmd() {
	"$BIT" --no-git-fallback "$@"
}

test_expect_success 'setup a six-commit origin' '
	git init -q -b main src &&
	(cd src &&
	 git config user.email test@example.com &&
	 git config user.name Test &&
	 git config commit.gpgsign false &&
	 for n in 1 2 3 4 5 6; do
		echo $n >f$n.txt &&
		git add . &&
		git commit -q -m "c$n" || exit 1
	 done) &&
	git clone -q --bare src origin.git &&
	git -C origin.git symbolic-ref HEAD refs/heads/main &&
	git -C origin.git config http.receivepack true
'

# The boundary is the oldest commit fetched, not the ref tip. Recording the tip
# makes the clone look parentless one commit in, so git walks less history than
# the repository actually holds. Comparing the objects on disk against what a
# boundary-honouring walk shows catches that; comparing two walks would not,
# since both would be truncated by the same wrong boundary.
#
# The loop runs in a subshell: `eval` runs a test body in the current shell, so
# a bare `exit` would abandon the whole file.
test_expect_success 'clone --depth keeps every fetched commit walkable' '
	( for depth in 1 2 3 4; do
		rm -rf "d$depth" &&
		bit_cmd clone -q --depth "$depth" "file://$(pwd)/origin.git" "d$depth" &&
		present=$(git -C "d$depth" cat-file --batch-all-objects --batch-check |
			grep -c commit) &&
		visible=$(git -C "d$depth" log --oneline | wc -l | tr -d " ") &&
		test "$present" = "$depth" &&
		test "$visible" = "$depth" || {
			echo "depth $depth: $present commits on disk, $visible walkable" >&2
			exit 1
		}
	  done )
'

test_expect_success 'clone --depth marks the repository shallow' '
	rm -rf d &&
	bit_cmd clone -q --depth 2 "file://$(pwd)/origin.git" d &&
	test "$(bit_cmd -C d rev-parse --is-shallow-repository)" = true
'

# rev-list used to emit the boundary commit'\''s parent, an id with no object
# behind it, so it reported one commit more than the repository holds.
test_expect_success 'rev-list stops at the boundary and matches log' '
	rm -rf d &&
	bit_cmd clone -q --depth 2 "file://$(pwd)/origin.git" d &&
	test "$(bit_cmd -C d rev-list --count HEAD)" = 2 &&
	test "$(bit_cmd -C d rev-list HEAD | wc -l)" = 2 &&
	test "$(bit_cmd -C d log --oneline | wc -l)" = 2 &&
	bit_cmd -C d rev-list HEAD | while read -r oid; do
		git -C d cat-file -e "$oid" || exit 1
	done
'

test_expect_success 'gc succeeds in a shallow clone and keeps every commit' '
	rm -rf d &&
	bit_cmd clone -q --depth 3 "file://$(pwd)/origin.git" d &&
	bit_cmd -C d gc &&
	test "$(bit_cmd -C d log --oneline | wc -l)" = 3
'

test_expect_success 'prune succeeds in a shallow clone' '
	rm -rf d &&
	bit_cmd clone -q --depth 3 "file://$(pwd)/origin.git" d &&
	bit_cmd -C d prune &&
	test "$(bit_cmd -C d log --oneline | wc -l)" = 3
'

# repack -ad used to pack only the tip and then delete the pack holding the
# rest, losing commits with a zero exit status.
test_expect_success 'repack -ad keeps every commit in a shallow clone' '
	( for depth in 1 2 3 4; do
		rm -rf "r$depth" &&
		bit_cmd clone -q --depth "$depth" "file://$(pwd)/origin.git" "r$depth" &&
		before=$(git -C "r$depth" cat-file --batch-all-objects --batch-check |
			grep -c commit) &&
		bit_cmd -C "r$depth" repack -ad &&
		after=$(git -C "r$depth" cat-file --batch-all-objects --batch-check |
			grep -c commit) &&
		test "$before" = "$after" || {
			echo "depth $depth: repack lost commits, $before -> $after" >&2
			exit 1
		}
	  done )
'

test_expect_success 'fsck is clean in a shallow clone' '
	rm -rf d &&
	bit_cmd clone -q --depth 2 "file://$(pwd)/origin.git" d &&
	bit_cmd -C d fsck
'

test_expect_success 'committing on top of a shallow tip keeps gc and fsck happy' '
	rm -rf d &&
	bit_cmd clone -q --depth 2 "file://$(pwd)/origin.git" d &&
	echo new >d/new.txt &&
	bit_cmd -C d add . &&
	bit_cmd -C d commit -q -m "on top of shallow" &&
	test "$(bit_cmd -C d rev-list --count HEAD)" = 3 &&
	bit_cmd -C d gc &&
	bit_cmd -C d fsck
'

test_expect_success 'fetch --unshallow completes the history' '
	rm -rf d &&
	bit_cmd clone -q --depth 2 "file://$(pwd)/origin.git" d &&
	bit_cmd -C d fetch --unshallow &&
	test "$(bit_cmd -C d rev-list --count HEAD)" = 6 &&
	test_path_is_missing d/.git/shallow &&
	bit_cmd -C d fsck
'

test_expect_success 'fetch --depth deepens to the requested depth' '
	rm -rf d &&
	bit_cmd clone -q --depth 1 "file://$(pwd)/origin.git" d &&
	bit_cmd -C d fetch --depth 4 &&
	test "$(bit_cmd -C d rev-list --count HEAD)" = 4
'

# The native HTTP clone used to drop the shallow lines entirely, leaving a
# repository that was shallow in content but reported itself complete, so
# --unshallow afterwards had nothing to deepen from.
if command -v node >/dev/null 2>&1; then
	PORT=$((10000 + $$ % 50000))
	SERVER_PID=""

	cleanup_http() {
		if test -n "$SERVER_PID"; then
			kill "$SERVER_PID" 2>/dev/null || true
			SERVER_PID=""
		fi
	}
	trap 'cleanup_http; cleanup' EXIT

	test_expect_success 'start a smart HTTP server' '
		USE_REAL_GIT=1 node "$BIT_BUILD_DIR/tools/http-test-server.js" \
			"$(pwd)/src" "$PORT" >server.log 2>&1 &
		SERVER_PID=$! &&
		ready= &&
		for _ in 1 2 3 4 5 6 7 8 9 10; do
			if git ls-remote "http://localhost:$PORT" >/dev/null 2>&1; then
				ready=yes
				break
			fi
			sleep 1
		done &&
		test -n "$ready"
	'

	# The tear-down must not sit at the end of the && chain: `cmd || true`
	# there would swallow every assertion before it and the test could never
	# fail. It belongs in the EXIT trap above.
	test_expect_success 'http clone --depth records the boundary and can unshallow' '
		rm -rf h &&
		bit_cmd clone -q --depth 2 "http://localhost:$PORT" h &&
		test_path_is_file h/.git/shallow &&
		test "$(bit_cmd -C h rev-parse --is-shallow-repository)" = true &&
		test "$(bit_cmd -C h rev-list --count HEAD)" = 2 &&
		bit_cmd -C h fetch --unshallow &&
		test "$(bit_cmd -C h rev-list --count HEAD)" = 6
	'
else
	test_skip "http shallow clone" "node not found"
fi

test_done
