#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 SHARD_INDEX SHARD_TOTAL [ALLOWLIST]" >&2
  exit 1
fi

shard_index="$1"
shard_total="$2"
allowlist="${3:-tools/git-test-allowlist.txt}"

python3 - <<'PY' "$allowlist" "$shard_index" "$shard_total"
import sys
from pathlib import Path

allowlist = Path(sys.argv[1])
idx = int(sys.argv[2])
total = int(sys.argv[3])

if idx < 1 or idx > total:
    raise SystemExit(f"shard_index must be 1..{total}")

lines = allowlist.read_text().splitlines()
items = [line.strip() for line in lines if line.strip() and not line.strip().startswith('#')]
selected = [t for i, t in enumerate(items) if i % total == (idx - 1)]
print(' '.join(selected))
PY
