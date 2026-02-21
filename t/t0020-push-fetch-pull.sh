#!/bin/bash
#
# Test push, fetch, and pull operations using local bare repos
# All tests use git_cmd (--no-git-fallback), no real git required.
#
# Most push/pull tests pin origin to file:// URLs for stable local transport.

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

make_named_origin_and_work() {
    local name="$1"
    local marker="$2"
    git_cmd init "source_${name}" &&
    (cd "source_${name}" &&
        echo "$marker" > peer.txt &&
        git_cmd add peer.txt &&
        git_cmd commit -m "initial ${name}"
    ) &&
    git_cmd clone --bare "source_${name}" "origin-${name}.git" &&
    rm -rf "source_${name}" &&
    git_cmd clone "origin-${name}.git" "work-${name}" &&
    (cd "work-${name}" &&
        git_cmd remote set-url origin "file://$(cd .. && pwd)/origin-${name}.git"
    )
}

setup_fake_ssh_command() {
    mkdir -p mock-bin &&
    cat > mock-bin/ssh <<'EOF' &&
#!/bin/sh
log_file="${BIT_TEST_SSH_LOG:-}"
if [ -n "$log_file" ]; then
    printf '%s\n' "$*" >> "$log_file"
fi
host="$1"
shift
if [ "${1:-}" = "env" ]; then
    shift
    export "$1"
    shift
fi
cmd="$1"
shift
if [ "$#" -gt 0 ]; then
    exec "$cmd" "$@"
fi
exec sh -c "$cmd"
EOF
    chmod +x mock-bin/ssh &&
    export PATH="$(pwd)/mock-bin:$PATH"
}

RELAY_PORT=""
RELAY_PID=""

start_relay_test_server() {
    RELAY_PORT=$((12000 + RANDOM % 30000))
    node "$PROJECT_ROOT/tools/relay-test-server.js" "$RELAY_PORT" > relay.log 2>&1 &
    RELAY_PID=$!
    sleep 1
    kill -0 "$RELAY_PID"
}

stop_relay_test_server() {
    if [ -n "$RELAY_PID" ]; then
        kill "$RELAY_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$RELAY_PID" 2>/dev/null || true
        RELAY_PID=""
    fi
}

relay_test_url() {
    echo "relay+http://127.0.0.1:$RELAY_PORT"
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

test_expect_success 'fetch git@host:path remote updates remote-tracking refs' '
    command -v git-upload-pack >/dev/null &&
    make_origin_and_work &&
    setup_fake_ssh_command &&
    export BIT_TEST_SSH_LOG="$(pwd)/ssh.log" &&
    origin_abs="$(pwd)/origin.git" &&
    git_cmd clone "git@localhost:$origin_abs" work2 &&
    before_ref=$(git_cmd -C work2 show-ref | awk '"'"'$2=="refs/remotes/origin/main" { print $1 }'"'"') &&
    (cd work &&
        echo "ssh-fetch" > ssh-fetch.txt &&
        git_cmd add ssh-fetch.txt &&
        git_cmd commit -m "ssh fetch commit" &&
        git_cmd push origin main
    ) &&
    (cd work2 &&
        git_cmd fetch origin &&
        after_ref=$(git_cmd show-ref | awk '"'"'$2=="refs/remotes/origin/main" { print $1 }'"'"') &&
        test "$before_ref" != "$after_ref" &&
        git_cmd cat-file -p origin/main | grep -q "ssh fetch commit"
    ) &&
    test_grep "git-upload-pack" "$BIT_TEST_SSH_LOG"
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

# =============================================================================
# Group 4: relay clone/fetch/pull/push (2)
# =============================================================================

if ! command -v node >/dev/null 2>&1; then
    test_skip "relay clone/push/fetch/pull roundtrip via clone-announce peer" "node not found"
    test_skip "relay peer selection priority sender>repo>first works across clone/fetch/pull/push" "node not found"
else
test_expect_success "relay clone/push/fetch/pull roundtrip via clone-announce peer" '
    make_origin_and_work &&
    start_relay_test_server &&
    trap "stop_relay_test_server" EXIT &&
    relay_url=$(relay_test_url) &&
    origin_clone_url="file://$(pwd)/origin.git" &&
    (cd work &&
        BIT_RELAY_SENDER=node-a git_cmd hub sync clone-announce \
            "$relay_url" \
            --url "$origin_clone_url" \
            --repo relay-roundtrip
    ) &&
    git_cmd clone "$relay_url" relay-clone --relay-sender node-a --relay-repo relay-roundtrip &&
    (cd relay-clone &&
        echo "relay-change" > relay-change.txt &&
        git_cmd add relay-change.txt &&
        git_cmd commit -m "relay roundtrip commit" &&
        git_cmd push "$relay_url" main --relay-sender node-a --relay-repo relay-roundtrip
    ) &&
    relay_head=$(git_cmd -C relay-clone rev-parse HEAD) &&
    origin_head=$(git_cmd -C origin.git show-ref | awk '"'"'$2=="refs/heads/main" { print $1 }'"'"') &&
    test "$relay_head" = "$origin_head" &&
    (cd work &&
        git_cmd fetch "$relay_url" --relay-sender node-a --relay-repo relay-roundtrip &&
        fetched_head=$(git_cmd rev-parse refs/remotes/origin/main) &&
        test "$fetched_head" = "$origin_head" &&
        git_cmd pull "$relay_url" main --relay-sender node-a --relay-repo relay-roundtrip &&
        test_file_exists relay-change.txt &&
        git_cmd log --oneline | grep -q "relay roundtrip commit"
    ) &&
    stop_relay_test_server &&
    trap - EXIT
'

test_expect_success "relay peer selection priority sender>repo>first works across clone/fetch/pull/push" '
    make_named_origin_and_work a from-a &&
    make_named_origin_and_work b from-b &&
    start_relay_test_server &&
    trap "stop_relay_test_server" EXIT &&
    relay_url=$(relay_test_url) &&
    root_dir=$(pwd) &&
    origin_a_clone_url="file://$root_dir/origin-a.git" &&
    origin_b_clone_url="file://$root_dir/origin-b.git" &&
    (cd work-a &&
        BIT_RELAY_SENDER=node-a git_cmd hub sync clone-announce \
            "$relay_url" \
            --url "$origin_a_clone_url" \
            --repo repo-a
    ) &&
    (cd work-b &&
        BIT_RELAY_SENDER=node-b git_cmd hub sync clone-announce \
            "$relay_url" \
            --url "$origin_b_clone_url" \
            --repo repo-b
    ) &&
    git_cmd clone "$relay_url" client-sender --relay-sender node-a --relay-repo repo-b &&
    test "$(cat client-sender/peer.txt)" = "from-a" &&
    (cd client-sender &&
        echo "sender-priority" > sender-priority.txt &&
        git_cmd add sender-priority.txt &&
        git_cmd commit -m "sender priority push" &&
        git_cmd push "$relay_url" main --relay-sender node-a --relay-repo repo-b
    ) &&
    sender_head=$(git_cmd -C client-sender rev-parse HEAD) &&
    origin_a_head=$(git_cmd -C origin-a.git rev-parse refs/heads/main) &&
    origin_b_head=$(git_cmd -C origin-b.git rev-parse refs/heads/main) &&
    test "$sender_head" = "$origin_a_head" &&
    test "$sender_head" != "$origin_b_head" &&
    git_cmd clone "$relay_url" client-repo --relay-sender node-z --relay-repo repo-b &&
    test "$(cat client-repo/peer.txt)" = "from-b" &&
    (cd work-b &&
        echo "repo-fallback" > repo-fallback.txt &&
        git_cmd add repo-fallback.txt &&
        git_cmd commit -m "repo fallback update" &&
        git_cmd push origin main
    ) &&
    expected_b_head=$(git_cmd -C origin-b.git rev-parse refs/heads/main) &&
    (cd client-repo &&
        git_cmd fetch "$relay_url" --relay-sender node-z --relay-repo repo-b &&
        fetched_head=$(git_cmd rev-parse refs/remotes/origin/main) &&
        test "$fetched_head" = "$expected_b_head" &&
        git_cmd pull "$relay_url" main --relay-sender node-z --relay-repo repo-b &&
        test_file_exists repo-fallback.txt
    ) &&
    git_cmd clone "$relay_url" client-first --relay-sender node-z --relay-repo repo-z &&
    test "$(cat client-first/peer.txt)" = "from-a" &&
    stop_relay_test_server &&
    trap - EXIT
'
fi

test_done
