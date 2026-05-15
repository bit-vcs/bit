#!/usr/bin/env bash
# Compare bit vs real git on a custom repo URL.
# Usage: tools/compare-real-git-repo.sh <repo_url>
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <repo_url>" >&2
  exit 1
fi

REPO_URL="$1" bash tools/compare-real-git.sh
