#!/bin/bash
# Test HTTP backend with git-shim
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="/tmp/git-http-test-$$"
PORT=${1:-8765}

cleanup() {
  echo ""
  echo "[CLEANUP] Stopping server..."
  [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== Git HTTP Backend Test ==="
echo ""

# Build moongit
echo "[1/7] Building moongit..."
cd "$REPO_ROOT"
moon build --target native 2>/dev/null
mkdir -p tools/git-shim
cp _build/native/release/build/cmd/moongit/moongit.exe tools/git-shim/moon
echo "       Done."

# Create test repository
echo "[2/7] Creating test repository..."
mkdir -p "$TEST_DIR/repo"
git -C "$TEST_DIR/repo" init
git -C "$TEST_DIR/repo" config user.email "test@test.com"
git -C "$TEST_DIR/repo" config user.name "Test"
echo "Hello World" > "$TEST_DIR/repo/README.md"
git -C "$TEST_DIR/repo" add .
git -C "$TEST_DIR/repo" commit -m "Initial commit"
echo "       Commit: $(git -C "$TEST_DIR/repo" rev-parse --short HEAD)"

# Start HTTP server
echo "[3/7] Starting HTTP server on port $PORT..."
node "$SCRIPT_DIR/http-test-server.js" "$TEST_DIR/repo" $PORT > "$TEST_DIR/server.log" 2>&1 &
SERVER_PID=$!
sleep 2

if ! kill -0 $SERVER_PID 2>/dev/null; then
  echo "       ERROR: Server failed to start"
  cat "$TEST_DIR/server.log"
  exit 1
fi
echo "       Server PID: $SERVER_PID"

# Test 1: info/refs
echo "[4/7] Testing /info/refs?service=git-upload-pack..."
HTTP_CODE=$(curl -s -o "$TEST_DIR/info-refs.txt" -w "%{http_code}" \
  "http://localhost:$PORT/info/refs?service=git-upload-pack")

if [ "$HTTP_CODE" != "200" ]; then
  echo "       FAIL: HTTP $HTTP_CODE"
  cat "$TEST_DIR/server.log"
  exit 1
fi

if grep -q "agent=git/moonbit" "$TEST_DIR/info-refs.txt"; then
  echo "       OK: MoonBit implementation detected"
else
  echo "       FAIL: Not using MoonBit implementation"
  cat "$TEST_DIR/info-refs.txt"
  exit 1
fi

# Test 2: Clone via HTTP
echo "[5/7] Testing git clone via HTTP..."
mkdir -p "$TEST_DIR/clone"
if git -C "$TEST_DIR/clone" clone "http://localhost:$PORT" test 2>"$TEST_DIR/clone.log"; then
  if [ -f "$TEST_DIR/clone/test/README.md" ]; then
    echo "       OK: Clone succeeded"
  else
    echo "       FAIL: README.md not found"
    exit 1
  fi
else
  echo "       FAIL: Clone failed"
  cat "$TEST_DIR/clone.log"
  cat "$TEST_DIR/server.log"
  exit 1
fi

# Test 3: Add new commit to server
echo "[6/7] Adding second commit to server..."
echo "Updated content" > "$TEST_DIR/repo/README.md"
git -C "$TEST_DIR/repo" add .
git -C "$TEST_DIR/repo" commit -m "Second commit"
echo "       Commit: $(git -C "$TEST_DIR/repo" rev-parse --short HEAD)"

# Test 4: Fetch
echo "[7/7] Testing git fetch..."
if git -C "$TEST_DIR/clone/test" fetch origin 2>"$TEST_DIR/fetch.log"; then
  git -C "$TEST_DIR/clone/test" merge origin/main --ff-only >/dev/null 2>&1
  if grep -q "Updated content" "$TEST_DIR/clone/test/README.md"; then
    echo "       OK: Fetch and merge succeeded"
  else
    echo "       FAIL: Content not updated"
    exit 1
  fi
else
  echo "       FAIL: Fetch failed"
  cat "$TEST_DIR/fetch.log"
  cat "$TEST_DIR/server.log"
  exit 1
fi

echo ""
echo "=== All HTTP tests passed! ==="
