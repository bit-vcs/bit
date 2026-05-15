#!/usr/bin/env bash
# Print raw + gzipped size of a file. Used by size-* tasks.
# Usage: tools/size-bytes.sh <path>
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <file>" >&2
  exit 1
fi
file="$1"

if [ ! -f "$file" ]; then
  echo "file not found: $file" >&2
  exit 1
fi

raw_bytes=$(wc -c < "$file" | tr -d ' ')
gzip_bytes=$(gzip -c "$file" | wc -c | tr -d ' ')
echo "file=$file"
echo "raw_bytes=$raw_bytes"
echo "gzip_bytes=$gzip_bytes"
