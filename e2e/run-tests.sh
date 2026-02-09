#!/bin/sh
#
# Compatibility wrapper: e2e tests moved to t/t000x-*.
# Delegates to the unified t/run-tests.sh runner.

set -e

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$TEST_DIR/.." && pwd)

if test $# -eq 0; then
	set -- t00
fi

exec "$PROJECT_ROOT/t/run-tests.sh" "$@"
