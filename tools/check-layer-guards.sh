#!/usr/bin/env bash
# Static guards enforced by `pkf run check` after type-checks succeed.
set -euo pipefail

if rg -n "OsFs::new|@process\\.run" modules/bit/src/runtime >/dev/null; then
  echo "runtime layer must not use OsFs::new or @process.run"
  exit 1
fi

if rg -n "run_storage_command_by_name\\(" modules \
  -g '!modules/bit/cmd/bit/storage_runtime.mbt' \
  -g '!modules/bit/cmd/bit/storage_runtime_wbtest.mbt' \
  -g '!modules/bit/cmd/bit/pkg.generated.mbti' >/dev/null; then
  echo "run_storage_command_by_name is only allowed in cmd storage_runtime boundary/wbtests"
  exit 1
fi
