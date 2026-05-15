#!/usr/bin/env bash
# Inspect which git-compat suites flaker sees as affected.
# Usage: tools/flaker-git-compat-affected.sh <changed>
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <changed>" >&2
  exit 1
fi

node tools/flaker-cli-wrapper.mjs affected --changed "$1"
