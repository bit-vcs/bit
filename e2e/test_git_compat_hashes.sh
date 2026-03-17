#!/bin/bash
#
# Test that bit produces git-compatible commit and tree hashes.
# Creates identical repos with git and bit, then compares object hashes.

set -e

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$TEST_DIR/.." && pwd)
BIT="${MOONGIT:-$PROJECT_ROOT/target/native/release/build/cmd/bit/bit.exe}"
if [ ! -f "$BIT" ] && [ -f "$PROJECT_ROOT/_build/native/release/build/cmd/bit/bit.exe" ]; then
    BIT="$PROJECT_ROOT/_build/native/release/build/cmd/bit/bit.exe"
fi
if [ ! -f "$BIT" ] && [ -f "$PROJECT_ROOT/tools/git-shim/moon" ]; then
    BIT="$PROJECT_ROOT/tools/git-shim/moon"
fi

if [ ! -f "$BIT" ]; then
    echo "Building bit..."
    (cd "$PROJECT_ROOT" && moon build --target native --release)
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counters
PASS_COUNT=0
FAIL_COUNT=0
TEST_COUNT=0

TRASH_DIR=""

cleanup() {
    if [ -n "$TRASH_DIR" ] && [ -d "$TRASH_DIR" ]; then
        rm -rf "$TRASH_DIR"
    fi
}
trap cleanup EXIT

check() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    TEST_COUNT=$((TEST_COUNT + 1))
    if [ "$expected" = "$actual" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${GREEN}ok $TEST_COUNT${NC} - $label"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${RED}not ok $TEST_COUNT${NC} - $label"
        echo "  expected: $expected"
        echo "  actual:   $actual"
    fi
}

# Fixed identity and timestamps for reproducibility
# Use "epoch +offset" format for bit compatibility
export GIT_AUTHOR_NAME="Test User"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test User"
export GIT_COMMITTER_EMAIL="test@example.com"
export GIT_AUTHOR_DATE="1705320000 +0000"
export GIT_COMMITTER_DATE="1705320000 +0000"

bit_cmd() {
    "$BIT" --no-git-fallback "$@"
}

# ============================================================
# Test 1: Single file commit — tree and commit hash match
# ============================================================

TRASH_DIR=$(mktemp -d)
export HOME="$TRASH_DIR"

GIT_REPO="$TRASH_DIR/git-repo"
BIT_REPO="$TRASH_DIR/bit-repo"

mkdir -p "$GIT_REPO" "$BIT_REPO"

# --- git side ---
(
    cd "$GIT_REPO"
    git init -q
    echo "hello world" > file.txt
    git add file.txt
    git commit -q -m "first commit"
)

# --- bit side ---
(
    cd "$BIT_REPO"
    bit_cmd init -q
    echo "hello world" > file.txt
    bit_cmd add file.txt
    bit_cmd commit -q -m "first commit"
)

GIT_TREE1=$(cd "$GIT_REPO" && git rev-parse HEAD^{tree})
BIT_TREE1=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD^{tree})
check "single file: tree hash matches" "$GIT_TREE1" "$BIT_TREE1"

GIT_COMMIT1=$(cd "$GIT_REPO" && git rev-parse HEAD)
BIT_COMMIT1=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD)
check "single file: commit hash matches" "$GIT_COMMIT1" "$BIT_COMMIT1"

rm -rf "$TRASH_DIR"

# ============================================================
# Test 2: Multiple commits with modifications and subdirectories
# ============================================================

TRASH_DIR=$(mktemp -d)
export HOME="$TRASH_DIR"

GIT_REPO="$TRASH_DIR/git-repo"
BIT_REPO="$TRASH_DIR/bit-repo"

mkdir -p "$GIT_REPO" "$BIT_REPO"

# --- git side ---
(
    cd "$GIT_REPO"
    git init -q

    # Commit 1: single file
    echo "alpha" > a.txt
    git add a.txt
    git commit -q -m "add a.txt"

    # Commit 2: add subdirectory
    export GIT_AUTHOR_DATE="1705323600 +0000"
    export GIT_COMMITTER_DATE="1705323600 +0000"
    mkdir -p sub
    echo "beta" > sub/b.txt
    git add sub/b.txt
    git commit -q -m "add sub/b.txt"

    # Commit 3: modify existing file
    export GIT_AUTHOR_DATE="1705327200 +0000"
    export GIT_COMMITTER_DATE="1705327200 +0000"
    echo "alpha-modified" > a.txt
    git add a.txt
    git commit -q -m "modify a.txt"
)

# --- bit side ---
(
    cd "$BIT_REPO"
    bit_cmd init -q

    # Commit 1
    echo "alpha" > a.txt
    bit_cmd add a.txt
    bit_cmd commit -q -m "add a.txt"

    # Commit 2
    export GIT_AUTHOR_DATE="1705323600 +0000"
    export GIT_COMMITTER_DATE="1705323600 +0000"
    mkdir -p sub
    echo "beta" > sub/b.txt
    bit_cmd add sub/b.txt
    bit_cmd commit -q -m "add sub/b.txt"

    # Commit 3
    export GIT_AUTHOR_DATE="1705327200 +0000"
    export GIT_COMMITTER_DATE="1705327200 +0000"
    echo "alpha-modified" > a.txt
    bit_cmd add a.txt
    bit_cmd commit -q -m "modify a.txt"
)

# Check all three commits (HEAD, HEAD~1, HEAD~2)
for ref in HEAD "HEAD~1" "HEAD~2"; do
    GIT_TREE=$(cd "$GIT_REPO" && git rev-parse "$ref^{tree}")
    BIT_TREE=$(cd "$BIT_REPO" && bit_cmd rev-parse "$ref^{tree}")
    check "multi-commit ($ref): tree hash matches" "$GIT_TREE" "$BIT_TREE"

    GIT_COMMIT=$(cd "$GIT_REPO" && git rev-parse "$ref")
    BIT_COMMIT=$(cd "$BIT_REPO" && bit_cmd rev-parse "$ref")
    check "multi-commit ($ref): commit hash matches" "$GIT_COMMIT" "$BIT_COMMIT"
done

rm -rf "$TRASH_DIR"

# ============================================================
# Test 3: Config-only identity (no env vars)
# ============================================================

TRASH_DIR=$(mktemp -d)
export HOME="$TRASH_DIR"

GIT_REPO="$TRASH_DIR/git-repo"
BIT_REPO="$TRASH_DIR/bit-repo"

mkdir -p "$GIT_REPO" "$BIT_REPO"

# Clear identity env vars for this section
unset GIT_AUTHOR_NAME
unset GIT_AUTHOR_EMAIL
unset GIT_COMMITTER_NAME
unset GIT_COMMITTER_EMAIL

# Keep timestamps fixed
export GIT_AUTHOR_DATE="1706781600 +0000"
export GIT_COMMITTER_DATE="1706781600 +0000"

# --- git side ---
(
    cd "$GIT_REPO"
    git init -q
    git config user.name "Config User"
    git config user.email "config@example.com"
    echo "config identity test" > config.txt
    git add config.txt
    git commit -q -m "config identity commit"
)

# --- bit side ---
(
    cd "$BIT_REPO"
    bit_cmd init -q
    bit_cmd config user.name "Config User"
    bit_cmd config user.email "config@example.com"
    echo "config identity test" > config.txt
    bit_cmd add config.txt
    bit_cmd commit -q -m "config identity commit"
)

GIT_TREE_CFG=$(cd "$GIT_REPO" && git rev-parse HEAD^{tree})
BIT_TREE_CFG=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD^{tree})
check "config-only identity: tree hash matches" "$GIT_TREE_CFG" "$BIT_TREE_CFG"

GIT_COMMIT_CFG=$(cd "$GIT_REPO" && git rev-parse HEAD)
BIT_COMMIT_CFG=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD)
check "config-only identity: commit hash matches" "$GIT_COMMIT_CFG" "$BIT_COMMIT_CFG"

rm -rf "$TRASH_DIR"

# ============================================================
# Test 4: Env-var identity with different values
# ============================================================

TRASH_DIR=$(mktemp -d)
export HOME="$TRASH_DIR"

GIT_REPO="$TRASH_DIR/git-repo"
BIT_REPO="$TRASH_DIR/bit-repo"

mkdir -p "$GIT_REPO" "$BIT_REPO"

export GIT_AUTHOR_NAME="Alice Author"
export GIT_AUTHOR_EMAIL="alice@authors.org"
export GIT_COMMITTER_NAME="Bob Committer"
export GIT_COMMITTER_EMAIL="bob@committers.org"
export GIT_AUTHOR_DATE="1710059400 +0000"
export GIT_COMMITTER_DATE="1710061200 +0000"

# --- git side ---
(
    cd "$GIT_REPO"
    git init -q
    echo "env var identity" > env.txt
    git add env.txt
    git commit -q -m "env var commit"
)

# --- bit side ---
(
    cd "$BIT_REPO"
    bit_cmd init -q
    echo "env var identity" > env.txt
    bit_cmd add env.txt
    bit_cmd commit -q -m "env var commit"
)

GIT_TREE_ENV=$(cd "$GIT_REPO" && git rev-parse HEAD^{tree})
BIT_TREE_ENV=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD^{tree})
check "env-var identity: tree hash matches" "$GIT_TREE_ENV" "$BIT_TREE_ENV"

GIT_COMMIT_ENV=$(cd "$GIT_REPO" && git rev-parse HEAD)
BIT_COMMIT_ENV=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD)
check "env-var identity: commit hash matches" "$GIT_COMMIT_ENV" "$BIT_COMMIT_ENV"

rm -rf "$TRASH_DIR"

# ============================================================
# Test 5: Nested subdirectories and multiple files
# ============================================================

TRASH_DIR=$(mktemp -d)
export HOME="$TRASH_DIR"

GIT_REPO="$TRASH_DIR/git-repo"
BIT_REPO="$TRASH_DIR/bit-repo"

mkdir -p "$GIT_REPO" "$BIT_REPO"

export GIT_AUTHOR_NAME="Test User"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test User"
export GIT_COMMITTER_EMAIL="test@example.com"
export GIT_AUTHOR_DATE="1711929600 +0000"
export GIT_COMMITTER_DATE="1711929600 +0000"

# --- git side ---
(
    cd "$GIT_REPO"
    git init -q
    mkdir -p a/b/c
    echo "root" > root.txt
    echo "level1" > a/l1.txt
    echo "level2" > a/b/l2.txt
    echo "level3" > a/b/c/l3.txt
    git add .
    git commit -q -m "nested dirs"
)

# --- bit side ---
(
    cd "$BIT_REPO"
    bit_cmd init -q
    mkdir -p a/b/c
    echo "root" > root.txt
    echo "level1" > a/l1.txt
    echo "level2" > a/b/l2.txt
    echo "level3" > a/b/c/l3.txt
    bit_cmd add .
    bit_cmd commit -q -m "nested dirs"
)

GIT_TREE_NESTED=$(cd "$GIT_REPO" && git rev-parse HEAD^{tree})
BIT_TREE_NESTED=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD^{tree})
check "nested dirs: tree hash matches" "$GIT_TREE_NESTED" "$BIT_TREE_NESTED"

GIT_COMMIT_NESTED=$(cd "$GIT_REPO" && git rev-parse HEAD)
BIT_COMMIT_NESTED=$(cd "$BIT_REPO" && bit_cmd rev-parse HEAD)
check "nested dirs: commit hash matches" "$GIT_COMMIT_NESTED" "$BIT_COMMIT_NESTED"

rm -rf "$TRASH_DIR"
TRASH_DIR=""

# ============================================================
# Summary
# ============================================================

echo ""
echo "# passed $PASS_COUNT of $TEST_COUNT test(s)"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "# failed $FAIL_COUNT test(s)"
    exit 1
fi
echo "1..$TEST_COUNT"
exit 0
