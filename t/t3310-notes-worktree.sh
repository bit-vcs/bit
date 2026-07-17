#!/bin/sh
#
# Notes in linked worktrees and with packed refs
#

test_description='git notes from linked worktrees and packed refs'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

test_expect_success 'setup: repo with two commits and a linked worktree' '
	mkdir repo &&
	(cd repo &&
	 $BIT init &&
	 echo "one" > file.txt &&
	 $BIT add file.txt &&
	 $BIT commit -m "c1" &&
	 echo "two" >> file.txt &&
	 $BIT add file.txt &&
	 $BIT commit -m "c2" &&
	 $BIT worktree add ../wt -b wt-branch)
'

test_expect_success 'notes add from main repo is visible in worktree' '
	(cd repo && $BIT notes add -m "note-from-main" HEAD) &&
	(cd wt &&
	 echo "note-from-main" > expect &&
	 $BIT notes show HEAD > actual &&
	 test_cmp expect actual)
'

test_expect_success 'notes list works from worktree' '
	(cd wt &&
	 $BIT notes list > list &&
	 test_line_count = list 1)
'

test_expect_success 'notes add from worktree is visible in main repo' '
	(cd wt &&
	 $BIT notes --ref=memory add -m "note-from-wt" HEAD) &&
	(cd repo &&
	 echo "note-from-wt" > expect &&
	 $BIT notes --ref=memory show HEAD > actual &&
	 test_cmp expect actual)
'

test_expect_success 'worktree notes ref is written to the common git dir' '
	test -f repo/.git/refs/notes/memory
'

test_expect_success 'notes append from worktree' '
	(cd wt &&
	 $BIT notes append -m "appended-in-wt" HEAD &&
	 $BIT notes show HEAD > actual &&
	 grep "note-from-main" actual &&
	 grep "appended-in-wt" actual)
'

test_expect_success 'notes show resolves HEAD~1 from worktree' '
	(cd wt &&
	 $BIT notes add -m "note-on-parent" HEAD~1 &&
	 echo "note-on-parent" > expect &&
	 $BIT notes show HEAD~1 > actual &&
	 test_cmp expect actual)
'

test_expect_success 'notes remove from worktree' '
	(cd wt &&
	 $BIT notes remove HEAD~1 &&
	 ! $BIT notes show HEAD~1)
'

test_expect_success 'log shows notes from worktree' '
	(cd wt &&
	 $BIT log -1 > log-out &&
	 grep "Notes:" log-out &&
	 grep "appended-in-wt" log-out)
'

test_expect_success 'setup: move notes ref into packed-refs' '
	(cd repo &&
	 note_commit=$(cat .git/refs/notes/commits) &&
	 rm .git/refs/notes/commits &&
	 {
		echo "# pack-refs with: peeled fully-peeled sorted" &&
		echo "$note_commit refs/notes/commits"
	 } >> .git/packed-refs)
'

test_expect_success 'notes show reads packed notes ref' '
	(cd repo &&
	 $BIT notes show HEAD > actual &&
	 grep "note-from-main" actual)
'

test_expect_success 'notes add on packed ref keeps existing notes' '
	(cd repo &&
	 $BIT notes add -m "note-on-parent-packed" HEAD~1 &&
	 $BIT notes show HEAD > actual &&
	 grep "note-from-main" actual &&
	 echo "note-on-parent-packed" > expect &&
	 $BIT notes show HEAD~1 > actual2 &&
	 test_cmp expect actual2)
'

test_expect_success 'packed notes ref readable from worktree' '
	(cd wt &&
	 $BIT notes show HEAD > actual &&
	 grep "note-from-main" actual)
'

test_done
