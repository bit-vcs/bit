///| Benchmarks for SHA-1 / SHA-256 primitives.
///
/// Run with:
///   moon bench -p mizchi/bit/hash --target native -f bench_test.mbt
///
/// Every git object read, write, and pack delta resolve goes through
/// one of these functions, so a few percent here flows everywhere.

///|
fn bench_make_bytes(len : Int) -> Bytes {
  // Deterministic non-zero payload — random-shaped enough to defeat
  // any compiler / hardware tricks that special-case all-zero input.
  Bytes::makei(len, fn(i) { ((i * 31 + 7) % 251).to_byte() })
}

///|
let bench_input_64 : Bytes = bench_make_bytes(64)

///|
let bench_input_1k : Bytes = bench_make_bytes(1024)

///|
let bench_input_8k : Bytes = bench_make_bytes(8 * 1024)

///|
let bench_input_64k : Bytes = bench_make_bytes(64 * 1024)

///|
test "bench sha1_raw 64 bytes" (b : @bench.T) {
  b.bench(fn() {
    let h = sha1_raw(bench_input_64)
    b.keep(h.length())
  })
}

///|
test "bench sha1_raw 1 KiB" (b : @bench.T) {
  b.bench(fn() {
    let h = sha1_raw(bench_input_1k)
    b.keep(h.length())
  })
}

///|
test "bench sha1_raw 8 KiB" (b : @bench.T) {
  b.bench(fn() {
    let h = sha1_raw(bench_input_8k)
    b.keep(h.length())
  })
}

///|
test "bench sha1_raw 64 KiB" (b : @bench.T) {
  b.bench(fn() {
    let h = sha1_raw(bench_input_64k)
    b.keep(h.length())
  })
}

///|
test "bench sha256_raw 1 KiB" (b : @bench.T) {
  b.bench(fn() {
    let h = sha256_raw(bench_input_1k)
    b.keep(h.length())
  })
}

///|
test "bench sha256_raw 8 KiB" (b : @bench.T) {
  b.bench(fn() {
    let h = sha256_raw(bench_input_8k)
    b.keep(h.length())
  })
}
