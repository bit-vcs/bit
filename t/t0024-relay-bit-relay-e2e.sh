#!/bin/bash
#
# e2e: real bit-relay roundtrip (clone/push + hub issue propagation)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT_CANDIDATE="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -z "${MOONGIT:-}" ] && [ -f "$PROJECT_ROOT_CANDIDATE/_build/native/release/build/cmd/bit/bit.exe" ]; then
    export MOONGIT="$PROJECT_ROOT_CANDIDATE/_build/native/release/build/cmd/bit/bit.exe"
fi

source "$(dirname "$0")/test-lib-e2e.sh"

BIT_RELAY_DIR="${BIT_RELAY_DIR:-$PROJECT_ROOT/../bit-relay}"
RELAY_PORT=""
RELAY_PID=""

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

start_bit_relay_server() {
    RELAY_PORT=$((20000 + RANDOM % 20000))
    HOST=127.0.0.1 PORT="$RELAY_PORT" RELAY_REQUIRE_SIGNATURE=false \
        deno run --allow-net --allow-env "$BIT_RELAY_DIR/src/deno_main.ts" > relay.log 2>&1 &
    RELAY_PID=$!

    for _ in $(seq 1 50); do
        if curl -fsS "http://127.0.0.1:$RELAY_PORT/health" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

stop_bit_relay_server() {
    if [ -n "$RELAY_PID" ]; then
        kill "$RELAY_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$RELAY_PID" 2>/dev/null || true
        RELAY_PID=""
    fi
}

relay_base_url() {
    echo "relay+http://127.0.0.1:$RELAY_PORT"
}

if ! command -v deno >/dev/null 2>&1; then
    test_skip "bit-relay e2e clone/push and hub issue propagation" "deno not found"
    test_done
fi

if ! command -v curl >/dev/null 2>&1; then
    test_skip "bit-relay e2e clone/push and hub issue propagation" "curl not found"
    test_done
fi

if [ ! -f "$BIT_RELAY_DIR/src/deno_main.ts" ]; then
    test_skip "bit-relay e2e clone/push and hub issue propagation" "bit-relay not found at $BIT_RELAY_DIR"
    test_done
fi

test_expect_success "bit-relay e2e clone/push and hub issue propagation" '
    make_origin_and_work &&
    start_bit_relay_server &&
    trap "stop_bit_relay_server" EXIT &&
    relay_room="relay-e2e-$RANDOM-$$" &&
    relay_token="token-$RANDOM-$$" &&
    relay_url=$(git_cmd hub sync issue-url "$(relay_base_url)" --room "$relay_room" --room-token "$relay_token") &&
    origin_clone_url="file://$(pwd)/origin.git" &&
    issue_title="relay-e2e-issue-$RANDOM-$$" &&
    (cd work &&
        BIT_RELAY_SENDER=node-a \
            git_cmd hub sync clone-announce \
                "$relay_url" \
                --url "$origin_clone_url" \
                --repo relay-e2e
    ) &&
    git_cmd clone "$relay_url" relay-clone --relay-sender node-a --relay-repo relay-e2e &&
    test_file_exists relay-clone/file.txt &&
    (cd relay-clone &&
        echo "relay-change" > relay-change.txt &&
        git_cmd add relay-change.txt &&
        git_cmd commit -m "relay roundtrip commit" &&
        git_cmd push "$relay_url" main --relay-sender node-a --relay-repo relay-e2e
    ) &&
    relay_head=$(git_cmd -C relay-clone rev-parse HEAD) &&
    origin_head=$(git_cmd -C origin.git show-ref | awk '"'"'$2=="refs/heads/main" { print $1 }'"'"') &&
    test "$relay_head" = "$origin_head" &&
    (cd work &&
        git_cmd hub init &&
        git_cmd hub issue create --title "$issue_title" --body "from relay-e2e source" &&
        BIT_RELAY_SENDER=node-a \
            git_cmd hub sync push "$relay_url"
    ) &&
    (cd relay-clone &&
        git_cmd hub init &&
        BIT_RELAY_SENDER=node-b git_cmd hub sync fetch "$relay_url" &&
        git_cmd hub issue list | grep -q "$issue_title"
    ) &&
    stop_bit_relay_server &&
    trap - EXIT
'

test_done
