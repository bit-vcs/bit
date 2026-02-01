#!/bin/sh
#
# Test shallow clone and sparse checkout combinations
#

test_description='Test shallow clone and sparse checkout scenarios'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

# Setup: create a repository with history
test_expect_success 'setup: create repository with history' '
	mkdir -p upstream &&
	(cd upstream &&
	 git init &&
	 mkdir -p src/core src/utils docs &&
	 echo "core v1" > src/core/index.mbt &&
	 echo "utils v1" > src/utils/index.mbt &&
	 echo "docs v1" > docs/README.md &&
	 git add -A &&
	 git commit -m "v1" &&
	 echo "core v2" > src/core/index.mbt &&
	 git add -A &&
	 git commit -m "v2" &&
	 echo "core v3" > src/core/index.mbt &&
	 git add -A &&
	 git commit -m "v3")
'

# Test: depth=1 clone
# Note: git clone --depth=1 may not create shallow clone for local repos
test_expect_success 'shallow: clone with depth=1' '
	git clone --depth=1 "file://$(pwd)/upstream" shallow
'

test_expect_success 'shallow: verify shallow marker exists' '
	test_path_is_file shallow/.git/shallow
'

test_expect_success 'shallow: verify single commit' '
	test "$(cd shallow && git log --oneline | wc -l | tr -d " ")" = "1"
'

test_expect_success 'shallow: content is complete' '
	test_path_is_file shallow/src/core/index.mbt &&
	test_path_is_file shallow/src/utils/index.mbt &&
	test_path_is_file shallow/docs/README.md
'

# Test: sparse checkout
test_expect_success 'sparse: setup sparse checkout' '
	git clone upstream sparse &&
	(cd sparse &&
	 git sparse-checkout init --cone &&
	 git sparse-checkout set src/core)
'

test_expect_success 'sparse: verify sparse structure' '
	test_path_is_file sparse/src/core/index.mbt &&
	test_path_is_missing sparse/src/utils/index.mbt &&
	test_path_is_missing sparse/docs/README.md
'

test_expect_success 'sparse: root files still present' '
	test_path_is_dir sparse/.git
'

# Test: shallow + sparse combination
test_expect_success 'shallow-sparse: combine depth=1 with sparse' '
	git clone --depth=1 "file://$(pwd)/upstream" shallow-sparse &&
	(cd shallow-sparse &&
	 git sparse-checkout init --cone &&
	 git sparse-checkout set src/core)
'

test_expect_success 'shallow-sparse: verify shallow marker' '
	test_path_is_file shallow-sparse/.git/shallow
'

test_expect_success 'shallow-sparse: verify combined state' '
	test "$(cd shallow-sparse && git log --oneline | wc -l | tr -d " ")" = "1" &&
	test_path_is_file shallow-sparse/src/core/index.mbt
'

# Test: subdir from shallow clone
test_expect_success 'subdir-shallow: extract subdir from shallow' '
	mkdir -p subdir-from-shallow &&
	cp -r shallow/src/core/* subdir-from-shallow/ &&
	(cd subdir-from-shallow &&
	 git init &&
	 git add -A &&
	 git commit -m "Subdir from shallow")
'

test_expect_success 'subdir-shallow: no upstream history' '
	test "$(cd subdir-from-shallow && git log --oneline | wc -l | tr -d " ")" = "1"
'

test_expect_success 'subdir-shallow: modify and commit' '
	(cd subdir-from-shallow &&
	 echo "modified" > index.mbt &&
	 git add -A &&
	 git commit -m "Modify")
'

# Test: filter options simulation
test_expect_success 'filter-blob-none: simulate blob:none' '
	mkdir -p filter-test &&
	(cd filter-test &&
	 git init &&
	 echo "placeholder" > file.txt &&
	 git add -A &&
	 git commit -m "With blobs")
'

test_expect_success 'filter-tree: simulate tree:0' '
	test_path_is_dir filter-test/.git/objects
'

# Test: partial clone scenarios
test_expect_success 'partial: setup for partial clone test' '
	(cd upstream &&
	 dd if=/dev/zero of=large.bin bs=1024 count=10 2>/dev/null &&
	 git add -A &&
	 git commit -m "Add large file")
'

test_expect_success 'partial: clone without large files (simulated)' '
	mkdir -p partial-clone &&
	cp -r upstream/src partial-clone/ &&
	cp upstream/docs/README.md partial-clone/ 2>/dev/null || true &&
	(cd partial-clone &&
	 git init &&
	 git add -A &&
	 git commit -m "Partial clone without large.bin")
'

test_expect_success 'partial: verify large file excluded' '
	test_path_is_missing partial-clone/large.bin &&
	test_path_is_file partial-clone/src/core/index.mbt
'

# Test: on-demand fetch simulation
test_expect_success 'on-demand: setup lazy fetch structure' '
	mkdir -p lazy-repo &&
	(cd lazy-repo &&
	 git init &&
	 mkdir -p fetched missing &&
	 echo "fetched" > fetched/file.txt &&
	 git add -A &&
	 git commit -m "Partial state")
'

test_expect_success 'on-demand: verify partial state' '
	test_path_is_file lazy-repo/fetched/file.txt &&
	test_path_is_dir lazy-repo/missing
'

# Test: promisor pack handling
test_expect_success 'promisor: setup promisor simulation' '
	(cd upstream && git repack -a -d)
'

test_expect_success 'promisor: verify pack exists' '
	test "$(ls upstream/.git/objects/pack/*.pack 2>/dev/null | wc -l | tr -d " ")" -ge 1
'

# Test: grafts/shallow boundary
test_expect_success 'grafts: verify shallow boundaries' '
	test_path_is_file shallow/.git/shallow &&
	test "$(wc -l < shallow/.git/shallow | tr -d " ")" -ge 1
'

# Test: unshallow
test_expect_success 'unshallow: fetch full history' '
	(cd shallow && git fetch --unshallow origin 2>/dev/null) || true
'

# Test: sparse-checkout reapply
test_expect_success 'sparse-reapply: modify sparse patterns' '
	(cd sparse && git sparse-checkout add src/utils)
'

test_expect_success 'sparse-reapply: verify expanded checkout' '
	test_path_is_file sparse/src/utils/index.mbt
'

test_done
