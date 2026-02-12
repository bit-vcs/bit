#!/bin/bash
#
# Test push, fetch, and pull operations using local bare repos
# All tests use git_cmd (--no-git-fallback), no real git required.
#
# Note: bit requires file:// URLs for local transport (plain paths fail).
# Pattern: create source -> clone --bare -> clone bare -> set file:// remote

source "$(dirname "$0")/test-lib-e2e.sh"

# Helper: create bare origin.git with one commit, clone to work dir.
# Sets up file:// URLs so push/fetch/pull work.
make_origin_and_work() {
    git_cmd init source_tmp &&
    (cd source_tmp &&
        echo "initial" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "initial commit"
    ) &&
    git_cmd clone --bare source_tmp origin.git &&
    rm -rf source_tmp &&
    git_cmd clone origin.git work &&
    (cd work &&
        git_cmd remote set-url origin "file://$(cd .. && pwd)/origin.git"
    )
}

# Helper: clone origin.git to a second working dir with file:// URL
clone_work2() {
    git_cmd clone origin.git work2 &&
    (cd work2 &&
        git_cmd remote set-url origin "file://$(cd .. && pwd)/origin.git"
    )
}

# =============================================================================
# Group 1: push (7)
# =============================================================================

test_expect_success 'push to bare repo updates ref' '
    make_origin_and_work &&
    (cd work &&
        echo "update" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "second" &&
        git_cmd push origin main
    ) &&
    commit_work=$(git_cmd -C work rev-parse HEAD) &&
    commit_origin=$(git_cmd -C origin.git show-ref | awk '"'"'$2=="refs/heads/main" { print $1 }'"'"') &&
    test "$commit_work" = "$commit_origin"
'

test_expect_success 'push new branch creates ref on remote' '
    make_origin_and_work &&
    (cd work &&
        git_cmd checkout -b feature &&
        echo "feat" > feat.txt &&
        git_cmd add feat.txt &&
        git_cmd commit -m "feature" &&
        git_cmd push origin feature
    ) &&
    git_cmd -C origin.git show-ref > refs_out &&
    grep -q " refs/heads/feature$" refs_out
'

test_expect_success 'push --force overwrites non-fast-forward' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work2 &&
        echo "diverge" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "diverge" &&
        git_cmd push origin main
    ) &&
    (cd work &&
        echo "conflict" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "conflict" &&
        git_cmd push --force origin main
    ) &&
    commit_work=$(git_cmd -C work rev-parse HEAD) &&
    commit_origin=$(git_cmd -C origin.git show-ref | awk '"'"'$2=="refs/heads/main" { print $1 }'"'"') &&
    test "$commit_work" = "$commit_origin"
'

test_expect_success 'push rejects non-fast-forward without --force' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work2 &&
        echo "diverge" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "diverge" &&
        git_cmd push origin main
    ) &&
    (cd work &&
        echo "conflict" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "conflict" &&
        test_must_fail git_cmd push origin main
    )
'

test_expect_success 'push --tags sends tags to remote' '
    make_origin_and_work &&
    (cd work &&
        git_cmd tag v1.0 &&
        git_cmd push --tags origin
    ) &&
    git_cmd -C origin.git show-ref > refs_out &&
    grep -q " refs/tags/v1.0$" refs_out
'

test_expect_success 'push --delete removes remote ref' '
    make_origin_and_work &&
    (cd work &&
        git_cmd checkout -b to-delete &&
        echo "temp" > temp.txt &&
        git_cmd add temp.txt &&
        git_cmd commit -m "temp branch" &&
        git_cmd push origin to-delete
    ) &&
    git_cmd -C origin.git show-ref > refs_before &&
    grep -q " refs/heads/to-delete$" refs_before &&
    (cd work &&
        git_cmd push --delete origin to-delete
    ) &&
    git_cmd -C origin.git show-ref > refs_after &&
    ! grep -q " refs/heads/to-delete$" refs_after
'

test_expect_success 'push -u sets upstream tracking' '
    make_origin_and_work &&
    (cd work &&
        git_cmd checkout -b tracked &&
        echo "track" > track.txt &&
        git_cmd add track.txt &&
        git_cmd commit -m "tracked" &&
        git_cmd push -u origin tracked &&
        git_cmd config branch.tracked.remote | grep -q "origin"
    )
'

# =============================================================================
# Group 2: fetch (5)
# =============================================================================

test_expect_success 'fetch updates remote-tracking refs' '
    make_origin_and_work &&
    clone_work2 &&
    before_ref=$(git_cmd -C work2 show-ref | awk '"'"'$2=="refs/remotes/origin/main" { print $1 }'"'"') &&
    (cd work &&
        echo "new" > new.txt &&
        git_cmd add new.txt &&
        git_cmd commit -m "new file" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        git_cmd fetch origin &&
        after_ref=$(git_cmd show-ref | awk '"'"'$2=="refs/remotes/origin/main" { print $1 }'"'"') &&
        test "$before_ref" != "$after_ref" &&
        git_cmd cat-file -p origin/main | grep -q "new file"
    )
'

test_expect_success 'fetch after remote push sees new commits' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        echo "c2" > c2.txt &&
        git_cmd add c2.txt &&
        git_cmd commit -m "commit two" &&
        echo "c3" > c3.txt &&
        git_cmd add c3.txt &&
        git_cmd commit -m "commit three" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        git_cmd fetch origin &&
        latest=$(git_cmd show-ref | awk '"'"'$2=="refs/remotes/origin/main" { print $1 }'"'"') &&
        git_cmd cat-file -p "$latest" | grep -q "commit three" &&
        parent=$(git_cmd cat-file -p "$latest" | grep "^parent " | cut -d" " -f2) &&
        git_cmd cat-file -p "$parent" | grep -q "commit two"
    )
'

test_expect_success 'fetch does not modify local branches' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        echo "new" > new.txt &&
        git_cmd add new.txt &&
        git_cmd commit -m "pushed" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        local_before=$(git_cmd rev-parse HEAD) &&
        git_cmd fetch origin &&
        local_after=$(git_cmd rev-parse HEAD) &&
        test "$local_before" = "$local_after"
    )
'

test_expect_success 'fetch --tags fetches tags' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        git_cmd tag v2.0 &&
        git_cmd push --tags origin
    ) &&
    (cd work2 &&
        git_cmd fetch --tags origin &&
        git_cmd tag | grep -q "v2.0"
    )
'

test_expect_success 'fetch with no changes is no-op' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work2 &&
        ref_before=$(git_cmd rev-parse origin/main) &&
        git_cmd fetch origin &&
        ref_after=$(git_cmd rev-parse origin/main) &&
        test "$ref_before" = "$ref_after"
    )
'

# =============================================================================
# Group 3: pull (6)
# =============================================================================

test_expect_success 'pull fast-forward updates' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        echo "ff" > ff.txt &&
        git_cmd add ff.txt &&
        git_cmd commit -m "fast forward" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        git_cmd pull origin main &&
        test_file_exists ff.txt &&
        git_cmd log --oneline | grep -q "fast forward"
    )
'

test_expect_success 'pull creates merge commit when diverged' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        echo "remote change" > remote.txt &&
        git_cmd add remote.txt &&
        git_cmd commit -m "remote side" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        echo "local change" > local.txt &&
        git_cmd add local.txt &&
        git_cmd commit -m "local side" &&
        git_cmd pull origin main &&
        git_cmd log --oneline | grep -q "Merge"
    )
'

test_expect_success 'pull --rebase rebases onto upstream' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        echo "upstream" > upstream.txt &&
        git_cmd add upstream.txt &&
        git_cmd commit -m "upstream change" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        echo "local" > local.txt &&
        git_cmd add local.txt &&
        git_cmd commit -m "local change" &&
        git_cmd pull --rebase origin main &&
        git_cmd log --oneline | grep -q "local change" &&
        git_cmd log --oneline | grep -q "upstream change" &&
        ! git_cmd log --oneline | grep -q "Merge"
    )
'

test_expect_success 'pull with no upstream configured fails gracefully' '
    git_cmd init standalone &&
    (cd standalone &&
        echo "x" > x.txt &&
        git_cmd add x.txt &&
        git_cmd commit -m "init" &&
        test_must_fail git_cmd pull
    )
'

test_expect_success 'pull on up-to-date repo is no-op' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work2 &&
        head_before=$(git_cmd rev-parse HEAD) &&
        git_cmd pull origin main &&
        head_after=$(git_cmd rev-parse HEAD) &&
        test "$head_before" = "$head_after"
    )
'

test_expect_success 'pull updates working tree files' '
    make_origin_and_work &&
    clone_work2 &&
    (cd work &&
        echo "new content" > file.txt &&
        git_cmd add file.txt &&
        git_cmd commit -m "update file" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        git_cmd pull origin main &&
        content=$(cat file.txt) &&
        test "$content" = "new content"
    )
'

test_done
