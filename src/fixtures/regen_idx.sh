#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

packs=(
  hello
  oracle
  oracle_deflate
  oracle_delta
  oracle_after_delta
  oracle_thin_base
)

for name in "${packs[@]}"; do
  pack_path="$DIR/${name}.pack"
  idx_path="$DIR/${name}.idx"
  git index-pack -o "$idx_path" "$pack_path" >/dev/null
  echo "wrote $idx_path"
done
