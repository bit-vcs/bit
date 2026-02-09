#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 SHARD_INDEX SHARD_TOTAL [ALLOWLIST] [WEIGHTS]" >&2
  exit 1
fi

shard_index="$1"
shard_total="$2"
allowlist="${3:-tools/git-test-allowlist.txt}"
weights="${4:-tools/git-test-runtime-seconds.tsv}"

python3 - <<'PY' "$allowlist" "$shard_index" "$shard_total" "$weights"
import sys
from pathlib import Path

allowlist = Path(sys.argv[1])
idx = int(sys.argv[2])
total = int(sys.argv[3])
weights_path = Path(sys.argv[4])

if idx < 1 or idx > total:
    raise SystemExit(f"shard_index must be 1..{total}")

lines = allowlist.read_text().splitlines()
items = [line.strip() for line in lines if line.strip() and not line.strip().startswith('#')]

# Backward compatible fallback: round-robin by line number.
if not weights_path.exists():
    selected = [t for i, t in enumerate(items) if i % total == (idx - 1)]
    print(' '.join(selected))
    raise SystemExit(0)

# Read per-script runtime weights (seconds) from TSV/space-separated lines:
#   t5302-pack-index.sh    9
weights = {}
for raw in weights_path.read_text().splitlines():
    s = raw.strip()
    if not s or s.startswith('#'):
        continue
    parts = s.replace('\t', ' ').split()
    if len(parts) < 2:
        continue
    name, value = parts[0], parts[1]
    try:
        parsed = int(value)
    except ValueError:
        continue
    if parsed < 1:
        parsed = 1
    weights[name] = parsed

# Greedy balancing by descending estimated runtime.
# Tie-breakers keep output deterministic.
loads = [0] * total
shard_of = {}
indexed = list(enumerate(items))
indexed.sort(key=lambda iv: (-weights.get(iv[1], 1), iv[0], iv[1]))
for _pos, test_name in indexed:
    shard = min(range(total), key=lambda s: (loads[s], s))
    loads[shard] += weights.get(test_name, 1)
    shard_of[test_name] = shard

# Preserve allowlist order inside each shard for readability/debuggability.
selected = [name for name in items if shard_of.get(name) == (idx - 1)]
print(' '.join(selected))
PY
