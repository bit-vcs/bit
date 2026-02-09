#!/bin/sh
#
# Run integration tests in the t/ directory.
# Usage:
#   ./t/run-tests.sh             # run all tests
#   ./t/run-tests.sh t000        # run tests whose file name contains t000
#   ./t/run-tests.sh -v t900     # verbose mode
#

set -e

cd "$(dirname "$0")"

verbose=0
filter=""

while test $# -gt 0; do
	case "$1" in
	-v|--verbose)
		verbose=1
		;;
	*)
		filter="$1"
		;;
	esac
	shift
done

passed=0
failed=0
total=0
failed_tests=""

echo "Running bit integration tests..."
if test -n "$filter"; then
	echo "Filter: $filter"
fi
echo

for test in t[0-9]*.sh; do
	if ! test -f "$test"; then
		continue
	fi
	if test -n "$filter"; then
		case "$test" in
		*"$filter"*) ;;
		*) continue ;;
		esac
	fi
	if ! test -x "$test"; then
		chmod +x "$test"
	fi

	total=$((total + 1))
	echo "=== $test ==="
	if test "$verbose" -eq 1; then
		if ./"$test"; then
			passed=$((passed + 1))
		else
			failed=$((failed + 1))
			failed_tests="$failed_tests $test"
			echo "FAILED: $test"
		fi
	else
		if output=$("./$test" 2>&1); then
			echo "$output"
			passed=$((passed + 1))
		else
			echo "$output"
			failed=$((failed + 1))
			failed_tests="$failed_tests $test"
			echo "FAILED: $test"
		fi
	fi
	echo
done

if test "$total" -eq 0; then
	echo "No tests matched filter: $filter"
	exit 1
fi

echo "========================================"
echo "Total:  $total"
echo "Passed: $passed"
echo "Failed: $failed"
echo "========================================"

if test "$failed" -gt 0; then
	echo
	echo "Failed tests:"
	for t in $failed_tests; do
		echo "  - $t"
	done
	exit 1
fi
exit 0
