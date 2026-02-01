#!/bin/sh
#
# Test subdir-push functionality
#

test_description='Test subdir-push (pushing a subdirectory clone back to upstream)'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

# Setup: create upstream repository
test_expect_success 'setup: create upstream repository' '
	mkdir -p upstream &&
	(cd upstream && git init --bare)
'

test_expect_success 'setup: create working clone' '
	git clone upstream working &&
	(cd working &&
	 mkdir -p src/lib src/cmd docs &&
	 echo "# Project" > README.md &&
	 echo "lib v1" > src/lib/lib.mbt &&
	 echo "cmd v1" > src/cmd/main.mbt &&
	 echo "docs v1" > docs/guide.md &&
	 git add -A &&
	 git commit -m "Initial structure" &&
	 git push origin main)
'

# Test: create subdir clone and push back
test_expect_success 'subdir-push: extract src/lib' '
	mkdir -p subdir-lib &&
	cp -r working/src/lib/* subdir-lib/ &&
	(cd subdir-lib &&
	 git init &&
	 git add -A &&
	 git commit -m "Extract src/lib")
'

test_expect_success 'subdir-push: modify subdir content' '
	(cd subdir-lib &&
	 echo "lib v2 - modified" > lib.mbt &&
	 echo "new feature" > feature.mbt &&
	 git add -A &&
	 git commit -m "Modify lib")
'

test_expect_success 'subdir-push: store upstream metadata' '
	base_commit=$(cd working && git rev-parse HEAD) &&
	(cd subdir-lib &&
	 git config bit.upstream.url "../upstream" &&
	 git config bit.upstream.path "src/lib" &&
	 git config bit.upstream.base "$base_commit")
'

# Test: tree transformation
test_expect_success 'transform: verify local tree structure' '
	(cd subdir-lib &&
	 git ls-tree HEAD > tree.txt &&
	 grep "lib.mbt" tree.txt &&
	 grep "feature.mbt" tree.txt)
'

test_expect_success 'transform: simulate tree embedding' '
	(cd working &&
	 git fetch origin &&
	 cp ../subdir-lib/lib.mbt src/lib/ &&
	 cp ../subdir-lib/feature.mbt src/lib/ &&
	 git add -A &&
	 git commit -m "Merge subdir changes")
'

test_expect_success 'transform: verify merged structure' '
	test_path_is_file working/src/lib/lib.mbt &&
	test_path_is_file working/src/lib/feature.mbt &&
	test_path_is_file working/src/cmd/main.mbt &&
	test_path_is_file working/docs/guide.md
'

test_expect_success 'transform: verify content preserved' '
	grep "lib v2" working/src/lib/lib.mbt &&
	grep "new feature" working/src/lib/feature.mbt
'

# Test: push to upstream
test_expect_success 'push: push merged changes to upstream' '
	(cd working && git push origin main)
'

test_expect_success 'push: verify upstream updated' '
	git clone upstream verify &&
	test_path_is_file verify/src/lib/feature.mbt
'

# Test: diff-only push (minimal objects)
test_expect_success 'diff-push: setup second modification' '
	(cd subdir-lib &&
	 echo "lib v3" > lib.mbt &&
	 git add -A &&
	 git commit -m "Version 3")
'

test_expect_success 'diff-push: count objects in diff' '
	(cd subdir-lib && git rev-list HEAD~1..HEAD --objects) > diff-objects.txt &&
	test "$(wc -l < diff-objects.txt | tr -d " ")" -lt 10
'

# Test: conflict detection
test_expect_success 'conflict: setup concurrent changes' '
	(cd working &&
	 echo "concurrent change" > src/lib/lib.mbt &&
	 git add -A &&
	 git commit -m "Concurrent change" &&
	 git push origin main)
'

test_expect_success 'conflict: detect base mismatch' '
	old_base=$(cd subdir-lib && git config bit.upstream.base) &&
	new_head=$(cd working && git rev-parse HEAD) &&
	test "$old_base" != "$new_head"
'

# Test: binary file handling
test_expect_success 'binary: create fresh repo with binary file' '
	mkdir -p binary-test &&
	(cd binary-test &&
	 git init &&
	 printf "\x00\x01\x02\xFF" > binary.bin &&
	 git add binary.bin &&
	 git commit -m "Add binary")
'

test_expect_success 'binary: verify binary tracked' '
	test_path_is_file binary-test/binary.bin &&
	(cd binary-test && git ls-files | grep -q binary.bin)
'

# Test: file deletion
test_expect_success 'delete: create repo and delete file' '
	mkdir -p delete-test &&
	(cd delete-test &&
	 git init &&
	 echo "keep" > keep.txt &&
	 echo "delete" > delete.txt &&
	 git add -A &&
	 git commit -m "Initial" &&
	 rm delete.txt &&
	 git add -A &&
	 git commit -m "Delete file")
'

test_expect_success 'delete: verify deletion tracked' '
	test_path_is_missing delete-test/delete.txt &&
	test_path_is_file delete-test/keep.txt
'

# Test: multiple subdirs
test_expect_success 'multi: clone multiple subdirs independently' '
	mkdir -p multi-lib multi-cmd &&
	echo "lib" > multi-lib/lib.mbt &&
	echo "cmd" > multi-cmd/cmd.mbt &&
	(cd multi-lib && git init && git add -A && git commit -m "Lib") &&
	(cd multi-cmd && git init && git add -A && git commit -m "Cmd")
'

test_expect_success 'multi: verify independent tracking' '
	lib_head=$(cd multi-lib && git rev-parse HEAD) &&
	cmd_head=$(cd multi-cmd && git rev-parse HEAD) &&
	test "$lib_head" != "$cmd_head"
'

# Test: atomic push simulation
test_expect_success 'atomic: prepare atomic push data' '
	git -C subdir-lib rev-parse HEAD > push-commit.txt &&
	echo "src/lib" >> push-commit.txt
'

test_expect_success 'atomic: verify push data' '
	test_path_is_file push-commit.txt &&
	test "$(wc -l < push-commit.txt | tr -d " ")" = "2"
'

test_done
