# e2e Compatibility Directory

`e2e/` tests were migrated into `t/` (`t000x-*`).

- Primary runner: `./t/run-tests.sh`
- Legacy wrapper: `./e2e/run-tests.sh` (delegates to `t/run-tests.sh t00`)

Use this directory only for backward-compatible entrypoints.
