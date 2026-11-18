# mizchi/x

Node.js backend compatibility layer for `moonbitlang/core/async` in [MoonBit](https://docs.moonbitlang.com).

`mizchi/x` keeps native behavior by delegating to `moonbitlang/core/async`, and provides JS FFI implementations so the same async-style code can run on `--target js` (Node.js) with minimal changes.

## Primary Goal

- Run code written against `moonbitlang/core/async` on Node.js (`--target js`).
- Keep native (`--target native`) semantics close by forwarding to upstream implementations.

## Related Package

- `mizchi/x`: API is aligned with `moonbitlang/core/async` contracts (native-compatible surface).
- `mizchi/js/node`: API is aligned with raw Node.js/JavaScript style APIs.

## Dependencies

| Dependency | Version |
|---|---|
| `moonbitlang/core/async` | bundled with MoonBit v0.10.20 |
| `moonbitlang/x` | 0.5.7 |
| `moonbitlang/regexp` | 0.3.7 |
| `@mizchi/jsimd-moonbit-interop` (npm, JS runtime) | 0.1.0 |

## Packages

| Package | Description |
|---|---|
| `mizchi/x/data` | Text/binary payload compatibility (`Data::text`, `Data::binary`, `Data::json`) |
| `mizchi/x/process` | Command execution (`run`, `spawn`, `spawn_orphan`, `wait_pid`, process pipes, file/stdio redirects, native pipe redirects, `collect_output`, `collect_stdout`, `collect_stderr`, `collect_output_merged`) |
| `mizchi/x/fs` | File system operations (`open`, `create`, `File`, `read_file`, `write_file`, `tmpdir`, `walk`, `Watcher`, `exists`, `mkdir`, `readdir`, `opendir`, `Directory::next`, `rename`, `remove`, `rmdir`) |
| `mizchi/x/http` | HTTP client/server (`get`, `post`, `put`, `get_stream`, `post_stream`, `put_stream`, `Client`, `Server`, `Cookie`) |
| `mizchi/x/gzip` | Gzip stream encoder/decoder (`Encoder`, `Decoder`) |
| `mizchi/x/tls` | TLS client/server streams (`Tls::client`, `Tls::server_from_pair` (server: JS only), peer certificate, channel binding, `rand_bytes`, `sha1`) |
| `mizchi/x/socket` | TCP/UDP sockets (`Addr`, `Tcp`, `TcpServer`, `UdpClient`, `UdpServer`) |
| `mizchi/x/signal` | Signal constants and global cancellation signal configuration (`Signal`, `to_int`, `set_global_cancellation_signals`) |
| `mizchi/x/raw_fd` | Raw file descriptor reads/writes (`RawFd::read`, `RawFd::write`, `RawFd::close`) |
| `mizchi/x/aqueue` | Async queue (`Queue`, `Kind`, `put`, `get`, `try_put`, `try_get`, `close`) |
| `mizchi/x/cond_var` | Async condition variable (`Cond::wait`, `Cond::signal`, `Cond::broadcast`) |
| `mizchi/x/semaphore` | Async semaphore (`Semaphore::acquire`, `release`, `try_acquire`) |
| `mizchi/x/websocket` | WebSocket client/server upgrade (`connect`, `from_http_server`, `Conn::send_text`, `Conn::send_binary`, `Conn::recv`, `Conn::close`) |
| `mizchi/x/stdio` | Standard I/O (`stdin`, `stdout`, `stderr` with `@io.BinaryReader`/`@io.BinaryWriter`) |
| `mizchi/x/pipe` | Pipes (`pipe()` → `PipeRead`/`PipeWrite` with `@io.BinaryReader`/`@io.BinaryWriter`): OS pipes on native (`pipe()` is `async`, with process redirect support), in-memory on JS |
| `mizchi/x/sys` | Environment variables and CLI args (`get_env_var`, `get_cli_args`, `exit`) |
| `mizchi/x/regexp` | Regular expressions mirroring `moonbitlang/regexp` (`compile`, `Regexp::execute`, `match_`, `group_by_name`, `group_count`, `group_names`, `MatchResult::matched`/`get`/`groups`/`results`/`before`/`after`) |
| `mizchi/x/json` | JSON mirroring `moonbitlang/core/json` (`parse`, `valid`, `stringify`) over the builtin `Json` value type |
| `mizchi/x/crypto` | Hashes / HMAC / hex mirroring `moonbitlang/x/crypto` (`md5`, `sha1`, `sha224`, `sha256`, `sm3`, `*_from_iter`, `hmac`, `MD5`/`SHA256`/`SM3` contexts, `bytes_to_hex_string`, `uints_to_hex_string`) |
| `mizchi/x/bytes` | Byte search, reverse search, equality, shortlex comparison, and non-ASCII detection; JS uses `@mizchi/jsimd-moonbit-interop` |
| `mizchi/x/bytes_view` | Copy-free `BytesView` byte/sequence search, reverse byte search, equality, shortlex comparison, and non-ASCII detection |
| `mizchi/x/string_view` | `StringView` substring/code-unit search, reverse search, and UTF-16 shortlex comparison through native JS string operations |
| `mizchi/x/array_view` | Byte-specialized `ArrayView` forward/reverse byte and sequence search through native JS array operations |

## Platform Support

| Package | native | js | wasm | wasm-gc |
|---|---|---|---|---|
| `data` | Yes | Yes | Yes | Yes |
| `process` | Yes | Yes | Yes* | stub |
| `fs` | Yes | Yes | Yes* | stub |
| `http` | Yes | Yes | Yes | stub |
| `gzip` | Yes | Yes | Yes | Yes |
| `tls` | client** | Yes | client** | stub |
| `socket` | TCP/UDP | TCP/UDP | TCP/UDP | stub |
| `signal` | Yes | constants/no-op | Yes | constants/no-op |
| `raw_fd` | Yes | Yes | stub | stub |
| `aqueue` | Yes | Yes | Yes | Yes |
| `cond_var` | Yes | Yes | Yes | Yes |
| `semaphore` | Yes | Yes | Yes | Yes |
| `websocket` | Yes | Yes | client | stub |
| `stdio` | Yes | Yes | Yes | stub |
| `pipe` | Unix | Yes | stub | stub |
| `sys` | Yes | Yes | Yes | Yes* |
| `regexp` | Yes | Yes (FFI) | Yes | Yes |
| `json` | Yes | Yes (FFI) | Yes | Yes |
| `crypto` | Yes | Yes | Yes | Yes |
| `bytes` | Yes | Yes (Wasm SIMD) | Yes | Yes |
| `bytes_view` | Yes | Yes (Wasm SIMD) | Yes | Yes |
| `string_view` | Yes | Yes (native UTF-16) | Yes | Yes |
| `array_view` | Yes | Yes (native byte search) | Yes | Yes |


- **Yes** — Full upstream-backed implementation.
- **Yes\*** — Implemented, with explicitly unsupported host-specific APIs.
- **client** — WebSocket client support; HTTP server upgrades are unavailable on wasm.
- **client\*\*** — TLS client only: `moonbitlang/core/async/tls` is client-only since MoonBit v0.10.21, so TLS server mode needs the JS target.
- **stub** — Compiles but aborts at runtime with "not supported" message.
- **Unix** — Native `pipe()` creates an OS pipe on Unix; on Windows it raises `PipeError(ENOSYS)`.
- **Yes\*** — Environment variables and arguments use `moonbitlang/core/env`; process exit remains unavailable on wasm-gc.

On `wasm`, filesystem, process, socket, TLS client, HTTP, WebSocket client, and stdio operations delegate to `moonbitlang/core/async`'s WASM host integration and retain the native/JS async signatures. They require capabilities granted by the WASM host (for example, `moonrun --policy` for filesystem, networking, and process spawning). `fs.Watcher`, `raw_fd`, `pipe`, process pipe redirection, and process groups, tree termination, and signal-based process termination are explicitly unsupported. Opaque WASM handles exposed as public `Int32` file descriptors abort if they cannot be represented without truncation.

## Upstream Compatibility

Tested with MoonBit `v0.10.20+65efd5b93` (2026-11-05), its bundled `moonbitlang/core/async`, `moonbitlang/x` 0.5.7, and `moonbitlang/regexp` 0.3.7. The standalone `moonbitlang/async` module is no longer a dependency.

Streams implement `moonbitlang/core/async/io.BinaryReader` and `BinaryWriter`. Compatibility methods such as `read_some`, `read_all`, `write`, `collect_output`, `read_file`, and `write_file` keep their text/binary payload interface through `mizchi/x/data.Data`; native adapters translate the new HTTP connections, process results, and filesystem timestamps. On JS, equivalent behavior is provided via `extern "js"` FFI (Node.js).

The workspace uses `moon.work` so `fswatch` resolves the local `mizchi/x` module. Run `just release-check-all` to validate the workspace across native, JS, wasm, and wasm-gc.

### Extension Notes

`mizchi/x/fs` now exposes the upstream-style `File` API (`open`, `create`, stream `@io.BinaryReader`/`@io.BinaryWriter`, random access, size, timestamps, sync, `tmpdir`, and `walk`) on native and Node.js. Native delegates to `moonbitlang/core/async/fs`; JS maps to `node:fs/promises`. JS file locking is not supported because Node.js has no standard advisory file-locking API.

`mizchi/x/socket` currently covers TCP and UDP on native and Node.js. Native delegates to `moonbitlang/core/async/socket`; JS maps TCP to `node:net` and UDP to `node:dgram`. Node.js does not expose stable OS file descriptors for these sockets, so `fd()` returns `-1` on JS. TCP connect/accept/run_forever and UDP unicast roundtrips are covered by automated tests. UDP multicast helpers are mapped to Node where available, but multicast is not covered by automated tests.

`mizchi/x/process` exposes process inputs/outputs, file redirection, `spawn`, `spawn_orphan`, `wait_pid`, `Process::wait`, `Process::try_wait`, and cancellation handlers. Native delegates to `moonbitlang/core/async/process`; JS maps to `node:child_process`.

`mizchi/x/http` includes response cookies and upstream-style streaming requests: `get_stream` returns a `Client`, while `post_stream`/`put_stream` return a writable `Client` whose response is obtained with `end_request()`. Native supports upstream proxy/trust options; JS returns `NotSupported` for proxy clients and custom TLS trust.

`mizchi/x/gzip` mirrors `moonbitlang/core/async/gzip` and works across native, JS, wasm, and wasm-gc via the upstream stream encoder/decoder.

`mizchi/x/regexp` mirrors the public surface of `moonbitlang/regexp`. On native, wasm, and wasm-gc it delegates to the pure-MoonBit engine. On JS it drives the host `RegExp` through FFI (using the `d` flag for capture offsets and scanning the source to number named/anonymous groups), returning the same `Regexp` / `MatchResult` API. Flag letters match upstream: `i` (ignore case), `m` (multiline), `s` (dot matches newline). The JS backend reports `Err::InternalError` for any pattern the host rejects, since it cannot classify parse failures as precisely as the native parser.

`mizchi/x/json` mirrors `parse` / `valid` / `stringify` from `moonbitlang/core/json`, reusing the builtin `Json` value type. On native, wasm, and wasm-gc it delegates to the pure-MoonBit implementation. On JS it uses the host `JSON.parse` / `JSON.stringify` through FFI and converts to/from `Json`. `max_nesting_depth` (default 1024) and `escape_slash` / `indent` are honored on both backends; the JS backend maps `JSON.parse` failures to `ParseError::InvalidEof` or `InvalidChar` with a best-effort position. All backends pass the ported `moonbitlang/core/json` parse suite (`json_upstream_test.mbt`).

`mizchi/x/crypto` re-exposes the synchronous hash / HMAC / hex surface of `moonbitlang/x/crypto` under the `mizchi/x` namespace, delegating to it on every target. Because `moonbitlang/x/crypto` is pure MoonBit it already runs on native, wasm, wasm-gc, and JS (including browsers), so the same synchronous signatures hold everywhere with no FFI. The `ByteSource` / `CryptoHasher` bounds and the `MD5` / `SHA256` / `SM3` contexts are the upstream types themselves (re-exported via `using`), so code written against `moonbitlang/x/crypto` is source-compatible. Note: the Web Crypto `crypto.subtle` API was intentionally **not** used — its `digest` / HMAC are async-only and cannot back this synchronous surface.

`mizchi/x/bytes` preserves the builtin `Bytes` contracts while replacing JS scalar hot paths with `@mizchi/jsimd-moonbit-interop`. The MoonBit JS backend imports this npm ESM package with `#module`; the interop package owns MoonBit-specific shortlex and reverse-substring semantics and delegates hot paths to `@mizchi/jsimd/bytes`. jsimd selects native JavaScript for small inputs and copies larger inputs into reusable prebuilt Wasm SIMD scratch memory.

`mizchi/x/bytes_view` passes the MoonBit JS runtime's `{ buf, start, end }` view directly to the interop package. It creates a zero-copy `Uint8Array.subarray` and uses the same jsimd Wasm SIMD kernels. Multi-byte reverse search is intentionally omitted because benchmarks showed no improvement over the builtin implementation.

`mizchi/x/string_view` preserves UTF-16 code-unit offsets and view bounds while using native JavaScript `indexOf` / `lastIndexOf` and string comparison. `mizchi/x/array_view` is byte-specialized and uses native array candidate searches without converting the backing JS Array to Wasm memory. Only measured wins are wrapped; `StringView` equality, generic `FixedArray`, and scalar-only ArrayView equality/comparison/non-ASCII scans are intentionally omitted.

The SIMD facade packages are optional. Applications only need the runtime package when they import
`mizchi/x/bytes`, `mizchi/x/bytes_view`, `mizchi/x/string_view`, or `mizchi/x/array_view` on the JS target:

```sh
pnpm add @mizchi/jsimd-moonbit-interop@0.1.0
```

Other `mizchi/x` packages neither resolve nor load this module, so applications that do not use these
facades can leave it uninstalled. CI verifies that case with `pnpm install --no-optional` and
`just test-js-without-jsimd`.

This repository declares the same exact version as an `optionalDependency`. During development it
overrides that dependency with the adjacent ghq checkout at `../jsimd/packages/moonbit-interop`;
build that package with `just build-moonbit-interop-package` in `mizchi/jsimd`, then run `pnpm install`
here.

### Benchmarks (JS target)

`*_bench_wbtest.mbt` files compare each package against its upstream engine with `moon bench --target js`. On native both sit on the same engine, so the numbers there are at parity (confirming the wrapper cost is negligible); the speedups below come from delegating to the host engine on JS. Representative run (Node.js, mean ns/iter, lower is better):

| Benchmark | `mizchi/x` (JS) | upstream (pure MoonBit) | Speedup |
|---|---|---|---|
| `regexp` execute (scan + match) | ~4.9 µs | ~167 µs | **~34×** |
| `regexp` execute + capture | ~5.1 µs | ~181 µs | **~35×** |
| `regexp` compile | ~0.95 µs | ~1.2 µs | ~1.3× |
| `json` valid | ~26 µs | ~73 µs | **~2.8×** |
| `json` stringify | ~30 µs | ~66 µs | **~2.2×** |
| `json` parse | ~67 µs | ~74 µs | ~on par |
| `bytes` find byte (4 KiB miss) | ~0.40 µs | ~1.94 µs | **~4.9×** |
| `bytes` equality (equal 4 KiB) | ~0.35 µs | ~1.54 µs | **~4.4×** |
| `bytes_view` find byte (4 KiB miss) | ~0.22 µs | ~1.14 µs | **~5.1×** |
| `bytes_view` equality (equal 4 KiB) | ~0.25 µs | ~1.49 µs | **~6.1×** |
| `string_view` find substring (4 KiB miss) | ~0.09 µs | ~3.57 µs | **~42×** |
| `string_view` compare (late difference) | ~0.20 µs | ~2.94 µs | **~15×** |
| `array_view` find sequence (4 KiB miss) | ~1.03 µs | ~2.01 µs | **~2.0×** |

`json` parse lands roughly on par rather than faster: `JSON.parse` is fast, but the dominant cost is rebuilding the MoonBit `Json` ADT (which the pure-MoonBit parser also pays), so the host parser's edge is largely consumed by marshalling. `valid` and `stringify` win clearly because they avoid that rebuild.

`mizchi/x/tls` mirrors `moonbitlang/core/async/tls`. Native delegates to the upstream OpenSSL/Schannel implementation, which is client-only since MoonBit v0.10.21: `Tls::server` / `Tls::server_from_pair` raise `TlsError` on native and wasm (terminate TLS in a proxy, or use the JS target), and `rand_bytes` reads the OS entropy source directly. JS maps to Node.js `node:tls` over any `@io.BinaryReader`/`@io.BinaryWriter` pair and supports client/server handshakes, graceful shutdown, peer certificate access, `tls-unique`/`tls-server-end-point` style channel bindings, `rand_bytes`, and `sha1`. WASM delegates to the upstream host-backed implementation; wasm-gc remains a stub.

`mizchi/x/websocket` mirrors the client API and exposes `from_http_server` for native `mizchi/x/http` server connections. JS and WASM support the client API; HTTP server upgrades are native-only.

`mizchi/x/signal` mirrors the async signal constants and delegates global cancellation signal setup to upstream on native and WASM. JS exposes portable numeric constants with a no-op global setup.

`mizchi/x/raw_fd` owns an existing OS file descriptor and provides single read/write operations. Native uses a small C FFI shim; JS maps to Node.js `fs.read`/`fs.write`/`fs.closeSync`. WASM targets compile as stubs.

`mizchi/x/aqueue`, `mizchi/x/cond_var`, and `mizchi/x/semaphore` are thin wrappers around the async synchronization primitives, keeping the same high-level API available from this compatibility module.

#### http (`moonbitlang/core/async/http`)

Upstream tests: 47 | Covered: 31 | Skipped: 16

| Upstream test | Status | Notes |
|---|---|---|
| `http request` | Covered | |
| `https request` | Covered | |
| `passthrough mode` | Covered | |
| `passthrough mode remaining data` | Covered | native |
| Parser/body/cookie/gzip/sender edge cases | Covered | `http_upstream_test.mbt` mirrors applicable upstream cases |
| `request streaming` | Covered | native and JS |
| Other 16 tests | Skip | Internal parser/sender/proxy tests |

#### websocket (`moonbitlang/core/async/websocket`)

Upstream tests: 24 | Covered: 1 | Skipped: 23

Most upstream tests are internal (frame handling, ping/pong, UTF-8 validation) and not applicable to the wrapper's high-level API. `CloseCode conversions` is covered directly; the wrapper also has independent tests covering its own API.

#### pipe (`moonbitlang/core/async/pipe`)

Upstream tests: 3 | Covered: 3 | Skipped: 0

All upstream pipe tests are fully covered.

#### stdio (`moonbitlang/core/async/stdio`)

Upstream tests: 3 | Covered: 3 | Skipped: 0

All upstream stdio/process redirect tests are covered on native and JS.

#### tls (`moonbitlang/core/async/tls`)

Upstream tests: 9 | Covered: 9 | Skipped: 0

| Upstream test | Status | Notes |
|---|---|---|
| `one way` | Covered | JS (needs a TLS server) |
| `echo` | Covered | JS (needs a TLS server) |
| `` `connect` accidental close `` | Covered | native and JS |
| `` `read` already closed `` | Covered | JS (needs a TLS server) |
| `client custom root certificate` | Covered | JS (needs a TLS server) |
| `client custom root certificate rejects different root` | Covered | JS (needs a TLS server) |
| `get_peer_certificate` | Covered | JS (needs a TLS server) |
| `channel binding` | Covered | JS (needs a TLS server) |
| `peer close connection` | Covered | JS (needs a TLS server) |

## Quick Start

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
```

### Upstream test coverage by package

Coverage is verified by `scripts/sync-upstream-tests.sh`, which extracts test names from the upstream packages and checks that each is either covered by a wrapper test or explicitly excluded in `scripts/upstream-exclude.conf`.

#### process (`moonbitlang/core/async/process`)

Upstream tests: 28 | Covered: 26 | Skipped: 2

| Upstream test | Status | Notes |
|---|---|---|
| `basic wait` | Covered | |
| `basic_ls` | Covered | |
| `collect_stdout` | Covered | |
| `collect_error` | Covered | |
| `collect_output` | Covered | |
| `collect_output blocked` | Covered | |
| `collect_output_merged` | Covered | |
| `wait exitcode` | Covered | |
| `set cwd` | Covered | |
| `set_env` | Covered | |
| `set_env no inherit` | Covered | |
| `wait_pid` | Covered | |
| `basic_cat` | Covered | |
| `cancel process` | Covered | |
| `cancel process hard` | Covered | |
| `cancel process timeout` | Covered | |
| `orphan process` | Covered | |
| `spawn_in_group wait` | Covered | |
| `spawn_in_group cancel` | Covered | |
| `Process::wait` | Covered | |
| `Process::try_wait` | Covered | |
| `Process:cancel` | Covered | |
| `merge stdout and stderr` | Covered | |
| `merge multiple` | Covered | |
| `redirect to file` | Covered | |
| `kill children on hard cancel` | Skip | requires custom test program + Windows |
| `do not kill orphan children on hard cancel` | Covered | |
| `windows command line arg escape` | Skip | Windows-specific |

## HTTP Server Operations (Node.js)

### Reverse proxy / TLS termination

When running `@http.Server` behind a reverse proxy (Nginx/Caddy/ALB), terminate TLS at the proxy and forward plain HTTP to the MoonBit process.

- Enable proxy-aware client address resolution with:
  - `@http.Server::new(..., trust_proxy=true)`
- Current JS behavior:
  - `client_addr()` uses `x-forwarded-for` (first hop) and `x-forwarded-port`
  - falls back to `x-forwarded-host` port when `x-forwarded-port` is absent

Security note: set `trust_proxy=true` only when requests are guaranteed to come from trusted proxy hops.

### SSE shutdown benchmark

Run this JS-only benchmark test to check concurrent SSE shutdown behavior:

```bash
moon test --target js src/http --filter 'bench(js): graceful close time under concurrent sse'
```

The test prints a measurement line like:

```text
bench(js): sse_clients=24 graceful_close_ms=1507
```

### k6 benchmark (default: JS vs Native)

Use the dedicated benchmark server package and k6 scenarios.
By default, this runs both `js` and `native` targets and prints a comparison summary.

```bash
./scripts/k6/run_http_bench.sh
```

Environment variables:

- `PORT` (default `18080`)
- `VUS` (default `128`)
- `DURATION` (default `20s`)
- `BODY_SIZE` (default `16384`) for `POST /consume`
- `TARGETS` (default `"js native"`)
  - e.g. `TARGETS=js` to run JS only
  - e.g. `TARGETS=native` to run Native only

Individual scenarios:

```bash
BASE_URL=http://127.0.0.1:18080 k6 run scripts/k6/http_ping.js
BASE_URL=http://127.0.0.1:18080 BODY_SIZE=16384 k6 run scripts/k6/http_consume.js
BASE_URL=http://127.0.0.1:18080 BODY_SIZE=16384 k6 run scripts/k6/http_discard.js
```

## License

Apache-2.0
