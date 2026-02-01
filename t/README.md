# Test Suite for bit

This directory contains shell-based integration tests for bit, following the Git project's testing conventions.

## Running Tests

```bash
# Run all tests
./t/run-tests.sh

# Run a single test
./t/t9000-subdir-clone.sh

# Run with verbose output
BIT_TEST_VERBOSE=1 ./t/t9000-subdir-clone.sh

# Keep trash directories for debugging
BIT_TEST_KEEP_TRASH=1 ./t/t9000-subdir-clone.sh
```

## Test Naming Convention

Tests are numbered in the format `tNNNN-description.sh`:

- `t0xxx` - Basic functionality
- `t1xxx` - Object handling
- `t2xxx` - Index operations
- `t3xxx` - Branch operations
- `t5xxx` - Remote operations
- `t9xxx` - bit-specific features (subdir-clone, etc.)

## Writing Tests

Tests use `test-lib.sh` which provides:

- `test_expect_success 'description' 'commands'` - Run a test
- `test_expect_failure 'description' 'commands'` - Expect failure
- `test_skip 'description' 'reason'` - Skip a test
- `test_cmp file1 file2` - Compare files
- `test_path_is_file path` - Check file exists
- `test_path_is_dir path` - Check directory exists
- `test_path_is_missing path` - Check path doesn't exist
- `test_done` - Finish and report results

Example:

```sh
#!/bin/sh
test_description='My test'
. ./test-lib.sh

test_expect_success 'create a file' '
    echo "content" > file.txt &&
    test_path_is_file file.txt
'

test_done
```

## Test Files

| File | Description |
|------|-------------|
| `t9000-subdir-clone.sh` | Subdir-clone: cloning subdirectories |
| `t9001-subdir-push.sh` | Subdir-push: pushing changes back upstream |
| `t9002-shallow-sparse.sh` | Shallow clone and sparse checkout |
