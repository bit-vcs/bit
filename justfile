# MoonBit Project Commands

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check (js + wasm + native)
check:
    moon check --deny-warn --warn-list=-27 --target js
    moon check --deny-warn --warn-list=-27 --target wasm
    moon check --deny-warn --warn-list=-27 --target native
    @if rg -n "OsFs::new|@process\\.run" src/runtime >/dev/null; then \
      echo "runtime layer must not use OsFs::new or @process.run"; \
      exit 1; \
    fi
    @if rg -n "run_storage_command_by_name\\(" src \
      -g '!src/cmd/bit/storage_runtime.mbt' \
      -g '!src/cmd/bit/storage_runtime_wbtest.mbt' \
      -g '!src/cmd/bit/pkg.generated.mbti' >/dev/null; then \
      echo "run_storage_command_by_name is only allowed in cmd storage_runtime boundary/wbtests"; \
      exit 1; \
    fi

# Run tests (js target: main packages only, native: all)
test:
    moon test --target js -p mizchi/bit -p mizchi/bit/lib
    moon test --target wasm -p mizchi/bit/runtime -f storage_runtime_wbtest.mbt
    moon test --target native --no-parallelize -j 1
    just test-git-compat-allowlist
    just test-flaker-affected-rules
    just test-flaker-cli-wrapper
    just test-flaker-git-compat
    just test-js-build

# Update snapshot tests (both js and native)
test-update:
    moon test --update --target js -p mizchi/bit -p mizchi/bit/lib
    moon test --update --target native --no-parallelize -j 1

# Refresh git-compat shard weights from recent GitHub Actions timing artifacts
update-git-test-runtime-seconds branch='main' runs='10' shards='10':
    python3 tools/update-git-test-runtime-seconds.py --branch {{branch}} --runs {{runs}} --shards {{shards}}

# Run main (native)
run:
    moon run src/main --target native

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean
    @bash tools/clean-git-test-artifacts.sh

# Build native binary
build:
    moon build --target native --release
    @mkdir -p tools/git-shim
    @bin_path="_build/native/release/build/cmd/bit/bit.exe"; \
    if [ ! -x "$bin_path" ]; then \
      echo "bit binary not found at $bin_path"; \
      exit 1; \
    fi; \
    cp "$bin_path" tools/git-shim/moon
    @chmod +x tools/git-shim/moon

# Build JS-exported lib module
build-js-lib:
    moon build --target js --release src/lib

# Build JS CLI bundle for the npm wrapper
build-js-cli:
    moon build --target js --release src/cmd/bit

# Sync the checked-in npm wrapper's raw JS payload with the current build
sync-npm-lib-raw: build-js-lib
    cp _build/js/release/build/lib/lib.js npm/lib.raw.js

# Sync the npm CLI's CommonJS payload with the current JS build
sync-npm-bit-cjs: build-js-cli
    cp _build/js/release/build/cmd/bit/bit.js npm/bit.cjs

# Install local frontend tooling for the Vite playground
playground-install:
    pnpm install

# Start the Vite-powered playground in one command
playground-dev:
    moon build --target js --release src/lib
    @if [ ! -d node_modules ]; then pnpm install; fi
    pnpm run playground:dev

# Run automated Node tests against the built JS lib and npm wrapper
test-js-build: sync-npm-lib-raw sync-npm-bit-cjs bundle-js-lib-minimal bundle-js-lib-git-ops
    node --test tools/js-build.test.mjs tools/npm-lib.test.mjs tools/npm-cli.test.mjs tools/demo-relay.test.mjs tools/demo-editor-link.test.mjs tools/playground-commands.test.mjs tools/playground-view.test.mjs

# Guard compat-random allowlist against known upstream-oracle failures
test-git-compat-allowlist:
    node --test tools/git-compat-allowlist.test.mjs

# Verify flaker-focused git-compat inventory helpers
test-flaker-git-compat:
    node --test tools/flaker-git-compat.test.mjs

# Verify flaker git-compat affected mapping config and examples
test-flaker-affected-rules:
    node --test tools/flaker-affected-rules.test.mjs

# Verify flaker CLI wrapper guidance for unsupported resolver versions
test-flaker-cli-wrapper:
    node --test tools/flaker-cli-wrapper.test.mjs

# Verify JS-exported lib on a pure in-memory host
test-js-lib: build-js-lib
    node tools/verify-libgit2-js.mjs

test-js-lib-relay: build-js-lib
    node tools/verify-libgit2-relay.mjs

# Measure JS-exported lib size (raw + gzip)
size-js-lib: build-js-lib
    @file="_build/js/release/build/lib/lib.js"; \
    raw_bytes=$(wc -c < "$file" | tr -d ' '); \
    gzip_bytes=$(gzip -c "$file" | wc -c | tr -d ' '); \
    echo "file=$file"; \
    echo "raw_bytes=$raw_bytes"; \
    echo "gzip_bytes=$gzip_bytes"

# Run a representative git-ops consumer script against the JS lib exports
test-js-lib-git-ops: build-js-lib
    node tools/lib-js-git-ops.mjs

# Run a minimal consumer script against the JS lib exports
test-js-lib-minimal: build-js-lib
    node tools/lib-js-minimal.mjs

# Bundle the representative git-ops script with tree shaking enabled
bundle-js-lib-git-ops: build-js-lib
    mkdir -p target
    bun build --target browser --format esm --production \
      --outfile target/lib-js-git-ops.bundle.mjs \
      tools/lib-js-git-ops.mjs

# Bundle the minimal script with tree shaking enabled
bundle-js-lib-minimal: build-js-lib
    mkdir -p target
    bun build --target browser --format esm --production \
      --outfile target/lib-js-minimal.bundle.mjs \
      tools/lib-js-minimal.mjs

# Verify the bundled git-ops script still runs
test-js-lib-git-ops-bundle: bundle-js-lib-git-ops
    node target/lib-js-git-ops.bundle.mjs

# Verify the bundled minimal script still runs
test-js-lib-minimal-bundle: bundle-js-lib-minimal
    node target/lib-js-minimal.bundle.mjs

# Measure the bundled git-ops script size (raw + gzip)
size-js-lib-git-ops-bundle: bundle-js-lib-git-ops
    @file="target/lib-js-git-ops.bundle.mjs"; \
    raw_bytes=$(wc -c < "$file" | tr -d ' '); \
    gzip_bytes=$(gzip -c "$file" | wc -c | tr -d ' '); \
    echo "file=$file"; \
    echo "raw_bytes=$raw_bytes"; \
    echo "gzip_bytes=$gzip_bytes"

# Measure the bundled minimal script size (raw + gzip)
size-js-lib-minimal-bundle: bundle-js-lib-minimal
    @file="target/lib-js-minimal.bundle.mjs"; \
    raw_bytes=$(wc -c < "$file" | tr -d ' '); \
    gzip_bytes=$(gzip -c "$file" | wc -c | tr -d ' '); \
    echo "file=$file"; \
    echo "raw_bytes=$raw_bytes"; \
    echo "gzip_bytes=$gzip_bytes"

# Verify minimal API usage stays materially smaller after tree shaking
verify-js-lib-treeshake: bundle-js-lib-minimal bundle-js-lib-git-ops
    node tools/verify-lib-js-treeshake.mjs

# Build the checked-in browser demo bundle served from /docs
build-docs-demo: build-js-lib
    bun build --target browser --format esm --production \
      --outfile docs/demo/app.js \
      docs/demo/main.js

# Build the checked-in browser playground bundle served from /docs
build-docs-playground: build-js-lib
    @if [ ! -d node_modules ]; then pnpm install; fi
    pnpm run playground:build

# Build the GitHub Pages demo artifact
build-pages-demo: build-docs-demo build-docs-playground
    mkdir -p target/pages
    cp docs/demo/index.html target/pages/index.html
    cp docs/demo/styles.css target/pages/styles.css
    cp docs/demo/app.js target/pages/app.js
    mkdir -p target/pages/playground
    cp docs/playground/index.html target/pages/playground/index.html
    cp docs/playground/styles.css target/pages/playground/styles.css
    cp docs/playground/app.js target/pages/playground/app.js

# Measure the built GitHub Pages demo JS bundle
size-pages-demo: build-pages-demo
    @file="target/pages/app.js"; \
    raw_bytes=$(wc -c < "$file" | tr -d ' '); \
    gzip_bytes=$(gzip -c "$file" | wc -c | tr -d ' '); \
    echo "file=$file"; \
    echo "raw_bytes=$raw_bytes"; \
    echo "gzip_bytes=$gzip_bytes"

# Install bit to ~/.moon/bin
install:
    moon install ./src/cmd/bit
    codesign -fs - ~/.moon/bin/bit

# Uninstall bit
uninstall:
    @rm -f ~/.moon/bin/bit
    @echo "Removed ~/.moon/bin/bit"

# Run t00xx integration tests (legacy e2e set)
e2e:
    bash e2e/run-tests.sh

# Run subdir-clone/push integration tests (t/ directory)
test-subdir:
    @bash t/run-tests.sh t900

# Distributed agent/orchestration focused checks (excluding upstream git/t)
test-distributed:
    moon test --target native -p mizchi/bit/x/mcp
    moon test --target native -p mizchi/bit/x/rebase-ai
    moon test --target native -p mizchi/bit/x/hub
    moon test --target native -p mizchi/bit/x/hub/native
    moon test --target native -p mizchi/bit/x/kv

# Prepare an intentional rebase conflict to debug rebase-ai locally
test-ai:
    bash tools/test-ai.sh

# Pre-release check
release-check: fmt info check test verify-js-lib-treeshake e2e

# Run Git's upstream test suite (submodule at third_party/git)
git-t: build
    @tools/apply-git-test-patches.sh
    tools/run-git-test.sh

# Run pack-related Git tests (useful as an oracle for pack behavior)
git-t-pack: build
    @tools/apply-git-test-patches.sh
    tools/run-git-test.sh T='t5300-pack-object.sh t5302-pack-index.sh t5303-pack-corruption-resilience.sh t5315-pack-objects-compression.sh t5316-pack-delta-depth.sh t5351-unpack-large-objects.sh'

# Run a broader pack/idx/bitmap test set
git-t-pack-more: build
    @tools/apply-git-test-patches.sh
    tools/run-git-test.sh T='t5300-pack-object.sh t5302-pack-index.sh t5303-pack-corruption-resilience.sh t5306-pack-nobase.sh t5307-pack-missing-commit.sh t5308-pack-detect-duplicates.sh t5309-pack-delta-cycles.sh t5310-pack-bitmaps.sh t5311-pack-bitmaps-shallow.sh t5313-pack-bounds-checks.sh t5314-pack-cycle-detection.sh t5315-pack-objects-compression.sh t5316-pack-delta-depth.sh t5319-multi-pack-index.sh t5321-pack-large-objects.sh t5326-multi-pack-bitmaps.sh t5327-multi-pack-bitmaps-rev.sh t5329-pack-objects-cruft.sh t5331-pack-objects-stdin.sh t5332-multi-pack-reuse.sh t5334-incremental-multi-pack-index.sh t5351-unpack-large-objects.sh'

# Run protocol/fetch/push logic-heavy tests (no network dependencies)
git-t-hard: build
    @tools/apply-git-test-patches.sh
    tools/run-git-test.sh T='t5500-fetch-pack.sh t5504-fetch-receive-strict.sh t5512-ls-remote.sh t5515-fetch-merge-logic.sh t5516-fetch-push.sh t5528-push-default.sh t5529-push-errors.sh t5533-push-cas.sh t5535-fetch-push-symref.sh t5537-fetch-shallow.sh t5538-push-shallow.sh t5700-protocol-v1.sh t5702-protocol-v2.sh t5703-upload-pack-ref-in-want.sh t5704-protocol-violations.sh t5705-session-id-in-capabilities.sh'

# Run additional fetch/push edge cases (includes refspec, multi-remote, and http shallow)
git-t-hard-more: build
    @tools/apply-git-test-patches.sh
    tools/run-git-test.sh T='t5510-fetch.sh t5511-refspec.sh t5513-fetch-track.sh t5514-fetch-multiple.sh t5518-fetch-exit-status.sh t5525-fetch-tagopt.sh t5527-fetch-odd-refs.sh t5530-upload-pack-error.sh t5536-fetch-conflicts.sh t5539-fetch-http-shallow.sh'

# Run remaining protocol v2 bundle-uri and serve tests
git-t-proto-more: build
    @tools/apply-git-test-patches.sh
    tools/run-git-test.sh T='t5701-git-serve.sh t5710-promisor-remote-capability.sh t5730-protocol-v2-bundle-uri-file.sh t5731-protocol-v2-bundle-uri-git.sh t5732-protocol-v2-bundle-uri-http.sh t5750-bundle-uri-parse.sh'

# Run tests from allowlist file (tools/git-test-allowlist.txt)
git-t-allowlist: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="$(rg -v '^[[:space:]]*#' tools/git-test-allowlist.txt | rg -v '^[[:space:]]*$' | tr '\n' ' ')"

# Run allowlist using git-shim (defaults to system git fallback)
git-t-allowlist-shim: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" SHIM_CMDS="receive-pack" \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="$(rg -v '^[[:space:]]*#' tools/git-test-allowlist.txt | rg -v '^[[:space:]]*$' | tr '\n' ' ')"

# Run allowlist and force shim to error on specified subcommands
git-t-allowlist-shim-strict: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" \
    SHIM_CMDS="init add diff diff-files diff-index ls-files tag branch checkout switch commit log show reflog reset update-ref update-index status merge rebase clone push fetch pull mv notes stash rm submodule worktree config show-ref for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object ls-tree write-tree commit-tree receive-pack upload-pack pack-objects index-pack format-patch describe gc clean sparse-checkout restore blame grep shell" SHIM_STRICT=1 \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="$(rg -v '^[[:space:]]*#' tools/git-test-allowlist.txt | rg -v '^[[:space:]]*$' | tr '\n' ' ')"

# Run allowlist with random bit/real-git routing for intercepted subcommands.
# Usage: SHIM_RANDOM_RATIO=30 just git-t-allowlist-shim-random
git-t-allowlist-shim-random: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    shim_cmds="init status add commit log show branch checkout switch reset rebase stash cherry-pick diff diff-files diff-index merge tag rm mv config sparse-checkout restore rev-parse cat-file ls-files hash-object ls-tree write-tree show-ref update-ref symbolic-ref reflog worktree gc clean grep submodule revert notes bisect describe blame format-patch shortlog remote clone fetch pull push receive-pack upload-pack pack-objects index-pack shell"; \
    ratio="${SHIM_RANDOM_RATIO:-50}"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" SHIM_CMDS="$shim_cmds" \
    SHIM_RANDOM_MODE=1 SHIM_RANDOM_RATIO="$ratio" \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="$(rg -v '^[[:space:]]*#' tools/git-test-allowlist.txt | rg -v '^[[:space:]]*$' | tr '\n' ' ')"

# Generate compatibility table from allowlist
compat-table:
    @bash tools/generate-compat-table.sh

# Run randomized compatibility shard (PoC). Use env vars:
#   COMPAT_RANDOM_SHARD, COMPAT_RANDOM_SHARDS, COMPAT_RANDOM_SEED,
#   COMPAT_RANDOM_RATIO, COMPAT_RANDOM_OUTPUT_DIR
compat-random-run:
    bash tools/run-git-compat-random.sh

# Aggregate compatibility random run records (default: compat-random-results)
compat-random-aggregate results_dir="compat-random-results":
    bash tools/aggregate-git-compat-random.sh {{results_dir}}

# Focused local git-compat sampling via flaker
flaker-git-compat-sample strategy="weighted" count="25" changed="":
    @if { [ "{{strategy}}" = "affected" ] || [ "{{strategy}}" = "hybrid" ]; } && [ -z "{{changed}}" ]; then \
      echo "changed=... is required when strategy={{strategy}}" >&2; \
      exit 1; \
    fi
    @args="sample --strategy {{strategy}} --count {{count}}"; \
    if [ -n "{{changed}}" ]; then \
      args="$args --changed {{changed}}"; \
    fi; \
    node tools/flaker-cli-wrapper.mjs $args

# Focused local git-compat execution via flaker
flaker-git-compat-run strategy="weighted" count="25" changed="": build
    @if { [ "{{strategy}}" = "affected" ] || [ "{{strategy}}" = "hybrid" ]; } && [ -z "{{changed}}" ]; then \
      echo "changed=... is required when strategy={{strategy}}" >&2; \
      exit 1; \
    fi
    @args="run --strategy {{strategy}} --count {{count}}"; \
    if [ -n "{{changed}}" ]; then \
      args="$args --changed {{changed}}"; \
    fi; \
    node tools/flaker-cli-wrapper.mjs $args

# Inspect which git-compat suites flaker sees as affected
flaker-git-compat-affected changed:
    node tools/flaker-cli-wrapper.mjs affected --changed {{changed}}

# Trigger Git Compat Randomized workflow via workflow_dispatch
compat-random-dispatch shards="1" ratio="50" target_shard="0" seed="":
    @if ! command -v gh >/dev/null 2>&1; then \
      echo "gh CLI is required: https://cli.github.com/" >&2; \
      exit 1; \
    fi
    @gh workflow run .github/workflows/git-compat-random.yml -f shards={{shards}} -f ratio={{ratio}} -f target_shard={{target_shard}} -f seed={{seed}}

# Run TypeScript notifier to create issue from compat-random summary
compat-random-notify summary="compat-random-summary.md" matrix="sharded results":
    pnpm --dir tools/ci-notify install
    pnpm --dir tools/ci-notify run notify -- \
      --summary {{summary}} \
      --repo "$GITHUB_REPOSITORY" \
      --run-id "${GITHUB_RUN_ID:-local}" \
      --run-attempt "${GITHUB_RUN_ATTEMPT:-1}" \
      --run-url "${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/runs/${GITHUB_RUN_ID:-local}" \
      --workflow "Git Compat Randomized" \
      --matrix "{{matrix}}" \
      --issue-title "Git Compat Randomized failed" \
      --labels "ci,automated-report"

# Run a single test file in strict shim mode (e.g., just git-t-one t3200-branch.sh)
git-t-one test_file: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" \
    SHIM_CMDS="init receive-pack upload-pack pack-objects index-pack shell" SHIM_STRICT=1 \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="{{test_file}}"

# Run a single test file with strict shim + no real-git delegation
git-t-one-no-real-git test_file: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" \
    SHIM_CMDS="init receive-pack upload-pack pack-objects index-pack shell" SHIM_STRICT=1 \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="{{test_file}}"

# Run a single test file in strict shim mode with remote intercepted
git-t-one-remote test_file: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" \
    SHIM_CMDS="init receive-pack upload-pack pack-objects index-pack remote shell" SHIM_STRICT=1 \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="{{test_file}}"

# Run a single test file with random bit/real-git routing for intercepted subcommands.
# Usage: SHIM_RANDOM_RATIO=70 just git-t-one-random t3200-branch.sh
git-t-one-random test_file: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    shim_cmds="init status add commit log show branch checkout switch reset rebase stash cherry-pick diff diff-files diff-index merge tag rm mv config sparse-checkout rev-parse cat-file ls-files hash-object ls-tree write-tree show-ref update-ref symbolic-ref reflog worktree gc clean grep submodule revert notes bisect describe blame format-patch shortlog remote clone fetch pull push receive-pack upload-pack pack-objects index-pack shell"; \
    ratio="${SHIM_RANDOM_RATIO:-50}"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" SHIM_CMDS="$shim_cmds" \
    SHIM_RANDOM_MODE=1 SHIM_RANDOM_RATIO="$ratio" \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="{{test_file}}"

# Compare bit vs real git performance
compare-real-git:
    bash tools/compare-real-git.sh

# Compare with custom repo (e.g., just compare-real-git-repo https://github.com/foo/bar.git)
compare-real-git-repo repo_url:
    REPO_URL="{{repo_url}}" bash tools/compare-real-git.sh

# Run a single test with ALL moongit commands (no fallback)
git-t-full test_file: build
    @tools/apply-git-test-patches.sh
    @prefix=$(brew --prefix gettext); \
    real_git="$(pwd)/third_party/git/git"; \
    if [ -x "$real_git" ]; then \
      exec_path="$(pwd)/third_party/git"; \
      fallback_real_git="$(/usr/bin/which git)"; \
      if [ "$fallback_real_git" = "$real_git" ]; then \
        fallback_real_git=""; \
      fi; \
    else \
      real_git=$(/usr/bin/which git); \
      exec_path=$($real_git --exec-path); \
      fallback_real_git=""; \
    fi; \
    shim_dir="$(pwd)/tools/git-shim/bin"; \
    echo "$real_git" > tools/git-shim/real-git-path; \
    SHIM_REAL_GIT="$real_git" SHIM_REAL_GIT_FALLBACK="$fallback_real_git" SHIM_EXEC_PATH="$exec_path" \
    SHIM_MOON="$(pwd)/tools/git-shim/moon" \
    SHIM_CMDS="init status add commit log show branch checkout switch reset rebase stash cherry-pick diff diff-files diff-index merge tag rm mv config sparse-checkout restore rev-parse cat-file ls-files hash-object ls-tree write-tree show-ref update-ref update-index symbolic-ref reflog worktree gc clean grep submodule revert notes bisect describe blame format-patch shortlog remote clone fetch pull push receive-pack upload-pack pack-objects index-pack shell" SHIM_STRICT=1 \
    GIT_TEST_INSTALLED="$shim_dir" GIT_TEST_EXEC_PATH="$exec_path" \
    GIT_TEST_DEFAULT_HASH=sha1 \
    CPATH="$prefix/include" LDFLAGS="-L$prefix/lib" LIBRARY_PATH="$prefix/lib" \
    tools/run-git-test.sh T="{{test_file}}"

# Run all benchmarks
bench:
    moon bench --target native

# Run benchmarks by package
bench-fs:
    moon bench --target native -p mizchi/bit/x/fs -f bench_test.mbt

bench-fs-real:
    moon bench --target native -p mizchi/bit/x/fs -f bench_real_test.mbt

bench-kv:
    moon bench --target native -p mizchi/bit/x/kv

bench-lib:
    moon bench --target native -p mizchi/bit/lib

bench-init:
    moon bench --target native -p mizchi/bit/cmd/bit -f bench_init_wbtest.mbt

bench-midx-clone:
    moon bench --target native -p mizchi/bit/cmd/bit -f bench_midx_clone_wbtest.mbt

bench-e2e-clone-fetch:
    moon bench --target native -p mizchi/bit/cmd/bit -f bench_e2e_clone_fetch_wbtest.mbt

bench-status:
    moon bench --target native -p mizchi/bit/lib -f bench_status_test.mbt

bench-pack:
    moon bench --target native -p mizchi/bit/pack -f bench_test.mbt

bench-protocol:
    moon bench --target native -p mizchi/bit/protocol -f bench_test.mbt

bench-diff:
    moon bench --target native -p mizchi/bit/diff -f bench_test.mbt

bench-ops:
    moon bench --target native -p mizchi/bit/lib -f bench_ops_test.mbt

bench-log:
    moon bench --target native -p mizchi/bit/cmd/bit -f bench_log_wbtest.mbt

bench-grep:
    moon bench --target native -p mizchi/bit/cmd/bit -f bench_grep_wbtest.mbt

# Save benchmark results with a name
bench-save name:
    moon bench --target native 2>&1 | bash tools/bench-save.sh {{name}}

# Compare two most recent benchmark results
bench-compare *args:
    bash tools/bench-compare.sh {{args}}
