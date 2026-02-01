#!/bin/sh
#
# Run all tests in the t/ directory
#

set -e

cd "$(dirname "$0")"

passed=0
failed=0
total=0

echo "Running bit integration tests..."
echo

for test in t[0-9]*.sh; do
	if test -x "$test"; then
		total=$((total + 1))
		echo "=== $test ==="
		if ./"$test"; then
			passed=$((passed + 1))
		else
			failed=$((failed + 1))
			echo "FAILED: $test"
		fi
		echo
	fi
done

echo "========================================"
echo "Total:  $total"
echo "Passed: $passed"
echo "Failed: $failed"
echo "========================================"

if test "$failed" -gt 0; then
	exit 1
fi
exit 0
