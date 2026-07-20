#!/bin/sh
#
# gc reachability roots: all refs namespaces must keep objects alive
#

test_description='git gc keeps objects reachable from any refs namespace'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

test_expect_success 'setup: repo with commit' '
	mkdir repo &&
	(cd repo &&
	 $BIT init &&
	 echo "one" > file.txt &&
	 $BIT add file.txt &&
	 $BIT commit -m "c1")
'

test_expect_success 'notes survive bit gc' '
	(cd repo &&
	 $BIT notes add -m "important note" HEAD &&
	 $BIT gc -q &&
	 echo "important note" > expect &&
	 $BIT notes show HEAD > actual &&
	 test_cmp expect actual)
'

test_expect_success 'custom refs/agent ref keeps objects alive across gc' '
	(cd repo &&
	 blob=$(echo "memory fact" | $BIT hash-object -w --stdin) &&
	 mem_tree=$(echo "100644 blob $blob	fact.md" | $BIT mktree) &&
	 mem_commit=$(echo "memory" | $BIT commit-tree $mem_tree) &&
	 $BIT update-ref refs/agent/memory/main $mem_commit &&
	 $BIT gc -q &&
	 $BIT cat-file -p refs/agent/memory/main:fact.md > actual &&
	 echo "memory fact" > expect &&
	 test_cmp expect actual)
'

test_expect_success 'packed custom refs survive gc' '
	(cd repo &&
	 $BIT pack-refs --all &&
	 $BIT gc -q &&
	 $BIT notes show HEAD > actual &&
	 grep "important note" actual &&
	 $BIT cat-file -p refs/agent/memory/main:fact.md > actual2 &&
	 grep "memory fact" actual2)
'

test_expect_success 'symref file under refs does not break gc' '
	(cd repo &&
	 main_ref=$(cat .git/HEAD | sed "s/^ref: //") &&
	 mkdir -p .git/refs/remotes/origin &&
	 echo "ref: $main_ref" > .git/refs/remotes/origin/HEAD &&
	 $BIT gc -q &&
	 $BIT notes show HEAD > actual &&
	 grep "important note" actual)
'

test_expect_success 'dangling loose objects are still pruned' '
	(cd repo &&
	 orphan=$(echo "orphan blob" | $BIT hash-object -w --stdin) &&
	 orphan_path=.git/objects/$(echo $orphan | cut -c1-2)/$(echo $orphan | cut -c3-) &&
	 test -f $orphan_path &&
	 $BIT gc -q &&
	 ! test -f $orphan_path)
'

test_expect_success 'gc from linked worktree keeps shared refs alive' '
	(cd repo &&
	 $BIT worktree add ../wt -b wt-branch) &&
	(cd wt &&
	 $BIT gc -q) &&
	(cd repo &&
	 $BIT notes show HEAD > actual &&
	 grep "important note" actual &&
	 $BIT cat-file -p refs/agent/memory/main:fact.md > actual2 &&
	 grep "memory fact" actual2)
'

test_expect_success 'repository is valid for real git after gc' '
	(cd repo &&
	 git fsck --strict 2> fsck-err &&
	 ! grep -i "error" fsck-err &&
	 git notes show HEAD > actual &&
	 grep "important note" actual)
'

test_done
