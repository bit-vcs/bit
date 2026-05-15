#!/usr/bin/env bash
# Run the TypeScript notifier that creates an issue from a compat-random summary.
# Usage: tools/compat-random-notify.sh [summary] [matrix]
set -euo pipefail

summary="${1:-compat-random-summary.md}"
matrix="${2:-sharded results}"

pnpm --dir tools/ci-notify install
pnpm --dir tools/ci-notify run notify -- \
  --summary "$summary" \
  --repo "$GITHUB_REPOSITORY" \
  --run-id "${GITHUB_RUN_ID:-local}" \
  --run-attempt "${GITHUB_RUN_ATTEMPT:-1}" \
  --run-url "${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/runs/${GITHUB_RUN_ID:-local}" \
  --workflow "Git Compat Randomized" \
  --matrix "$matrix" \
  --issue-title "Git Compat Randomized failed" \
  --labels "ci,automated-report"
