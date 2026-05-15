#!/usr/bin/env bash
# Aggregate compatibility random run records.
# Usage: tools/compat-random-aggregate.sh [results_dir]
set -euo pipefail

results_dir="${1:-compat-random-results}"
bash tools/aggregate-git-compat-random.sh "$results_dir"
