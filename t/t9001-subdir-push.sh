#!/bin/sh
#
# Test the subdir-clone round trip: push local commits back to the upstream
# repository and bring upstream changes into the subdir-clone.
#

test_description='Test subdir-clone push and pull against the upstream repository'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

upstream_file() {
	git -C "$TRASH_DIRECTORY/upstream.git" show "main:$1"
}

# Commit in the upstream repository through a separate ordinary clone.
upstream_commit() {
	(cd "$TRASH_DIRECTORY/work" &&
	 git pull -q origin main &&
	 eval "$1" &&
	 git add -A &&
	 git commit -q -m "$2" &&
	 git push -q origin main)
}

test_expect_success 'setup: upstream repository with a subdirectory' '
	git init -q --bare -b main upstream.git &&
	git clone -q upstream.git work &&
	(cd work &&
	 mkdir -p src/lib src/cmd &&
	 echo "# Project" > README.md &&
	 echo "lib v1" > src/lib/lib.mbt &&
	 echo "util v1" > src/lib/util.mbt &&
	 echo "cmd v1" > src/cmd/main.mbt &&
	 git add -A &&
	 git commit -q -m "Initial structure" &&
	 git push -q origin main)
'

test_expect_success 'clone: subdir-clone checks out only the subdirectory' '
	$BIT subdir-clone "$TRASH_DIRECTORY/upstream.git" src/lib lib &&
	test_path_is_file lib/lib.mbt &&
	test_path_is_file lib/util.mbt &&
	test_path_is_missing lib/README.md &&
	test_path_is_missing lib/src
'

test_expect_success 'clone: the index matches the checkout' '
	(cd lib && git status --porcelain) >status.out &&
	test ! -s status.out
'

test_expect_success 'push: a local commit lands under the subdirectory' '
	(cd lib &&
	 echo "lib v2" > lib.mbt &&
	 echo "feature" > feature.mbt &&
	 $BIT add . &&
	 $BIT commit -q -m "Add feature" &&
	 $BIT push origin main) &&
	test "$(upstream_file src/lib/lib.mbt)" = "lib v2" &&
	test "$(upstream_file src/lib/feature.mbt)" = "feature" &&
	test "$(upstream_file src/cmd/main.mbt)" = "cmd v1" &&
	test "$(upstream_file README.md)" = "# Project" &&
	test "$(git -C upstream.git log -1 --format=%s main)" = "Add feature"
'

test_expect_success 'push: nothing new is up to date' '
	(cd lib && $BIT push origin main) >push.out &&
	grep "Everything up-to-date" push.out
'

test_expect_success 'push: several commits at once, after an earlier push' '
	before=$(git -C upstream.git rev-list --count main) &&
	(cd lib &&
	 echo "util v2" > util.mbt &&
	 $BIT add . &&
	 $BIT commit -q -m "util v2" &&
	 echo "util v3" > util.mbt &&
	 $BIT add . &&
	 $BIT commit -q -m "util v3" &&
	 $BIT push origin main) &&
	test "$(git -C upstream.git rev-list --count main)" = "$((before + 2))" &&
	test "$(git -C upstream.git log -2 --format=%s main | tr "\n" ,)" = "util v3,util v2," &&
	test "$(upstream_file src/lib/util.mbt)" = "util v3" &&
	git -C upstream.git fsck --no-progress
'

test_expect_success 'push: rejected when the upstream moved on' '
	upstream_commit "echo \"cmd v2\" > src/cmd/main.mbt" "Change cmd" &&
	(cd lib &&
	 echo "lib v3" > lib.mbt &&
	 $BIT add . &&
	 $BIT commit -q -m "lib v3" &&
	 ! $BIT push origin main) &&
	test "$(upstream_file src/cmd/main.mbt)" = "cmd v2" &&
	test "$(upstream_file src/lib/lib.mbt)" = "lib v2"
'

test_expect_success 'pull: syncs without pulling the rest of the repository in' '
	(cd lib && $BIT pull) &&
	test_path_is_missing lib/README.md &&
	test_path_is_missing lib/src &&
	test "$(cat lib/lib.mbt)" = "lib v3"
'

test_expect_success 'push: succeeds after pull and keeps the upstream change' '
	(cd lib && $BIT push origin main) &&
	test "$(upstream_file src/lib/lib.mbt)" = "lib v3" &&
	test "$(upstream_file src/cmd/main.mbt)" = "cmd v2"
'

test_expect_success 'pull: upstream subdirectory changes rebase local work' '
	upstream_commit "echo \"upstream util\" > src/lib/util.mbt" "Upstream util" &&
	(cd lib &&
	 echo "local" > local.mbt &&
	 $BIT add . &&
	 $BIT commit -q -m "Add local" &&
	 $BIT pull) &&
	test "$(cat lib/util.mbt)" = "upstream util" &&
	test "$(cat lib/local.mbt)" = "local" &&
	test "$(git -C lib log --format=%s -2 | tr "\n" ,)" = "Add local,Upstream util," &&
	(cd lib && git status --porcelain) >status.out &&
	test ! -s status.out
'

test_expect_success 'push: the rebased commit goes on top of the upstream change' '
	(cd lib && $BIT push origin main) &&
	test "$(upstream_file src/lib/local.mbt)" = "local" &&
	test "$(upstream_file src/lib/util.mbt)" = "upstream util" &&
	test "$(git -C upstream.git log -2 --format=%s main | tr "\n" ,)" = "Add local,Upstream util,"
'

test_expect_success 'pull: a conflict stops the rebase and --continue finishes it' '
	upstream_commit "echo \"upstream lib\" > src/lib/lib.mbt" "Upstream lib" &&
	(cd lib &&
	 echo "local lib" > lib.mbt &&
	 $BIT add . &&
	 $BIT commit -q -m "Local lib" &&
	 ! $BIT pull &&
	 echo "merged lib" > lib.mbt &&
	 $BIT add lib.mbt &&
	 GIT_EDITOR=true $BIT rebase --continue &&
	 $BIT push origin main) &&
	test "$(upstream_file src/lib/lib.mbt)" = "merged lib" &&
	test "$(git -C upstream.git log -2 --format=%s main | tr "\n" ,)" = "Local lib,Upstream lib,"
'

test_done
