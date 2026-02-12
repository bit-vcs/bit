#!/bin/bash
#
# Test git init command
#

source "$(dirname "$0")/test-lib-e2e.sh"

# =============================================================================
# Group 1: Basic init (existing 5 + 2 new)
# =============================================================================

test_expect_success 'git init creates .git directory' '
    git_cmd init &&
    test_dir_exists .git &&
    test_dir_exists .git/objects &&
    test_dir_exists .git/refs
'

test_expect_success 'git init creates HEAD file' '
    git_cmd init &&
    test_file_exists .git/HEAD &&
    grep -q "ref: refs/heads/main\|ref: refs/heads/master" .git/HEAD
'

test_expect_success 'git init creates config file' '
    git_cmd init &&
    test_file_exists .git/config
'

test_expect_success 'git init in existing repo is safe' '
    git_cmd init &&
    git_cmd init &&
    test_dir_exists .git
'

test_expect_success 'git init with directory argument' '
    git_cmd init myrepo &&
    test_dir_exists myrepo/.git
'

test_expect_success 'plain init sets core.bare=false' '
    git_cmd init &&
    test_grep "bare = false" .git/config
'

test_expect_success 'plain nested in bare' '
    git_cmd init --bare bare.git &&
    mkdir bare.git/inner &&
    (cd bare.git/inner && git_cmd init) &&
    test_dir_exists bare.git/inner/.git
'

# =============================================================================
# Group 2: bare init
# =============================================================================

test_expect_success 'init --bare' '
    git_cmd init --bare &&
    test_dir_exists objects &&
    test_dir_exists refs &&
    test_file_exists HEAD
'

test_expect_success 'init --bare with directory' '
    git_cmd init --bare myrepo.git &&
    test_dir_exists myrepo.git/objects &&
    test_dir_exists myrepo.git/refs &&
    test_file_exists myrepo.git/HEAD
'

test_expect_success 'GIT_DIR bare' '
    GIT_DIR=foo.git git_cmd init &&
    test_dir_exists foo.git/objects &&
    test_dir_exists foo.git/refs &&
    test_file_exists foo.git/HEAD
'

test_expect_success 'init --bare creates bare config' '
    git_cmd init --bare &&
    test_grep "bare = true" config
'

# =============================================================================
# Group 3: GIT_DIR / GIT_WORK_TREE
# =============================================================================

test_expect_success 'GIT_DIR with GIT_WORK_TREE creates non-bare' '
    mkdir work &&
    GIT_DIR=work/.git GIT_WORK_TREE=work git_cmd init &&
    test_dir_exists work/.git/objects &&
    test_dir_exists work/.git/refs &&
    test_grep "bare = false" work/.git/config
'

test_expect_success 'GIT_DIR & GIT_WORK_TREE config has bare=false' '
    mkdir work2 &&
    GIT_DIR=work2/.git GIT_WORK_TREE=work2 git_cmd init &&
    test_grep "bare = false" work2/.git/config
'

# =============================================================================
# Group 4: reinit
# =============================================================================

test_expect_success 'reinit outputs Reinitialized' '
    git_cmd init >output_first 2>&1 &&
    test_grep "Initialized empty" output_first &&
    git_cmd init >output_second 2>&1 &&
    test_grep "Reinitialized existing" output_second
'

test_expect_success 'reinit preserves existing objects' '
    git_cmd init &&
    echo "test content" > testfile &&
    git_cmd add testfile &&
    git_cmd commit -m "first" &&
    ls .git/objects/pack/ >objects_before 2>/dev/null || true &&
    find .git/objects -type f >objects_list_before &&
    git_cmd init &&
    find .git/objects -type f >objects_list_after &&
    test_file_exists .git/objects/pack || test "$(cat objects_list_before)" != ""
'

test_expect_success 'reinit preserves refs' '
    git_cmd init &&
    mkdir -p .git/refs/tags &&
    echo "dummy-ref-content" > .git/refs/tags/test-tag &&
    git_cmd init &&
    test_file_exists .git/refs/tags/test-tag &&
    test_grep "dummy-ref-content" .git/refs/tags/test-tag
'

# =============================================================================
# Group 5: template
# =============================================================================

test_expect_success 'init with --template' '
    mkdir -p tmpl/hooks &&
    echo "#!/bin/sh" > tmpl/hooks/pre-commit &&
    echo "custom" > tmpl/custom-file &&
    git_cmd init --template=tmpl &&
    test_file_exists .git/hooks/pre-commit &&
    test_file_exists .git/custom-file &&
    test_grep "custom" .git/custom-file
'

test_expect_success 'init with --template blank suppresses hooks' '
    git_cmd init --template= &&
    test_path_is_missing .git/hooks
'

test_expect_success 'init with GIT_TEMPLATE_DIR' '
    mkdir -p mytmpl/info &&
    echo "custom-exclude" > mytmpl/info/custom &&
    GIT_TEMPLATE_DIR=mytmpl git_cmd init &&
    test_file_exists .git/info/custom &&
    test_grep "custom-exclude" .git/info/custom
'

# =============================================================================
# Group 6: initial branch
# =============================================================================

test_expect_success 'initial-branch sets HEAD' '
    git_cmd init --initial-branch=trunk &&
    test_grep "ref: refs/heads/trunk" .git/HEAD
'

test_expect_success '-b shorthand works like --initial-branch' '
    git_cmd init -b develop &&
    test_grep "ref: refs/heads/develop" .git/HEAD
'

test_expect_success 'reinit with -b changes HEAD' '
    git_cmd init -b first &&
    test_grep "ref: refs/heads/first" .git/HEAD &&
    git_cmd init -b second &&
    test_grep "ref: refs/heads/second" .git/HEAD
'

# =============================================================================
# Group 7: separate git dir
# =============================================================================

test_expect_success 'init with --separate-git-dir' '
    mkdir work &&
    (cd work && git_cmd init --separate-git-dir=../realgit) &&
    test_file_exists work/.git &&
    test_dir_exists realgit/objects &&
    test_dir_exists realgit/refs &&
    test_grep "gitdir:" work/.git
'

test_expect_success 'separate-git-dir .git file has correct gitdir pointer' '
    mkdir work2 &&
    (cd work2 && git_cmd init --separate-git-dir=../realgit2) &&
    test_grep "gitdir:" work2/.git &&
    test_grep "realgit2" work2/.git
'

# =============================================================================
# Group 8: directory creation
# =============================================================================

test_expect_success 'init creates a new directory' '
    test_path_is_missing newdir &&
    git_cmd init newdir &&
    test_dir_exists newdir/.git
'

test_expect_success 'init creates a new bare directory' '
    test_path_is_missing newbare.git &&
    git_cmd init --bare newbare.git &&
    test_dir_exists newbare.git/objects
'

test_expect_success 'init creates a new deep directory' '
    test_path_is_missing a &&
    git_cmd init a/b/c &&
    test_dir_exists a/b/c/.git
'

test_expect_success 'init recreates a directory' '
    mkdir existingdir &&
    git_cmd init existingdir &&
    test_dir_exists existingdir/.git
'

test_expect_success 'init notices EEXIST on file' '
    echo "I am a file" > blocker &&
    test_must_fail git_cmd init blocker
'

# =============================================================================
# Group 9: quiet
# =============================================================================

test_expect_success 'init -q suppresses output' '
    git_cmd init -q >output 2>&1 &&
    test_must_be_empty output
'

test_done
