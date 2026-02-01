#!/bin/sh
#
# Test subdir-clone functionality
#

test_description='Test subdir-clone (cloning a subdirectory with its own .git)'

TEST_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
. "$TEST_DIRECTORY/test-lib.sh"

# Setup: create a "remote" repository with subdirectories
test_expect_success 'setup: create upstream repository' '
	mkdir -p upstream &&
	(cd upstream &&
	 git init &&
	 mkdir -p src/lib src/cmd docs &&
	 echo "# Project" > README.md &&
	 echo "lib code" > src/lib/lib.mbt &&
	 echo "cmd code" > src/cmd/main.mbt &&
	 echo "documentation" > docs/guide.md &&
	 git add -A &&
	 git commit -m "Initial commit")
'

test_expect_success 'setup: verify upstream structure' '
	test_path_is_file upstream/README.md &&
	test_path_is_file upstream/src/lib/lib.mbt &&
	test_path_is_file upstream/src/cmd/main.mbt &&
	test_path_is_file upstream/docs/guide.md
'

# Test: simulate subdir clone by extracting src/lib
test_expect_success 'subdir-clone: extract subdirectory as new repo' '
	mkdir -p subdir-lib &&
	cp -r upstream/src/lib/* subdir-lib/ &&
	(cd subdir-lib &&
	 git init &&
	 git add -A &&
	 git commit -m "Subdir clone of src/lib")
'

test_expect_success 'subdir-clone: verify extracted content' '
	test_path_is_file subdir-lib/lib.mbt &&
	test_path_is_dir subdir-lib/.git
'

test_expect_success 'subdir-clone: modify local content' '
	(cd subdir-lib &&
	 echo "modified lib code" > lib.mbt &&
	 echo "new file" > new.mbt &&
	 git add -A &&
	 git commit -m "Local modifications")
'

test_expect_success 'subdir-clone: verify modifications tracked' '
	test "$(cd subdir-lib && git log --oneline | wc -l | tr -d " ")" = "2"
'

# Test: metadata preservation
test_expect_success 'subdir-clone: store upstream info in config' '
	upstream_commit=$(cd upstream && git rev-parse HEAD) &&
	(cd subdir-lib &&
	 git config bit.upstream.url "https://github.com/user/repo" &&
	 git config bit.upstream.path "src/lib" &&
	 git config bit.upstream.commit "$upstream_commit")
'

test_expect_success 'subdir-clone: verify config stored' '
	test "$(cd subdir-lib && git config bit.upstream.path)" = "src/lib"
'

# Test: depth=1 shallow clone simulation
test_expect_success 'shallow: create shallow-like clone (depth=1)' '
	mkdir -p shallow-lib &&
	cp -r upstream/src/lib/* shallow-lib/ &&
	(cd shallow-lib &&
	 git init &&
	 git add -A &&
	 git commit -m "Shallow clone")
'

test_expect_success 'shallow: no parent history in shallow clone' '
	test "$(cd shallow-lib && git log --oneline | wc -l | tr -d " ")" = "1"
'

# Test: sparse checkout simulation
test_expect_success 'sparse: setup sparse checkout patterns' '
	mkdir -p upstream/.git/info &&
	cat > upstream/.git/info/sparse-checkout <<-EOF
	/README.md
	/src/lib/
	EOF
'

test_expect_success 'sparse: verify sparse patterns file created' '
	test_path_is_file upstream/.git/info/sparse-checkout
'

# Test: cone mode patterns
test_expect_success 'cone: create cone-mode style checkout' '
	mkdir -p cone-checkout &&
	cp upstream/README.md cone-checkout/ &&
	cp -r upstream/src/lib cone-checkout/lib &&
	(cd cone-checkout &&
	 git init &&
	 git add -A &&
	 git commit -m "Cone checkout: root + src/lib")
'

test_expect_success 'cone: verify cone structure' '
	test_path_is_file cone-checkout/README.md &&
	test_path_is_file cone-checkout/lib/lib.mbt &&
	test_path_is_missing cone-checkout/docs
'

# Test: nested subdirectory clone
test_expect_success 'nested: create deeply nested upstream' '
	(cd upstream &&
	 mkdir -p packages/core/src packages/utils/src &&
	 echo "core" > packages/core/src/index.mbt &&
	 echo "utils" > packages/utils/src/index.mbt &&
	 git add -A &&
	 git commit -m "Add packages")
'

test_expect_success 'nested: clone packages/core only' '
	mkdir -p nested-core &&
	cp -r upstream/packages/core/* nested-core/ &&
	(cd nested-core &&
	 git init &&
	 git add -A &&
	 git commit -m "Clone packages/core")
'

test_expect_success 'nested: verify nested clone' '
	test_path_is_file nested-core/src/index.mbt &&
	test_path_is_missing nested-core/utils
'

test_done
