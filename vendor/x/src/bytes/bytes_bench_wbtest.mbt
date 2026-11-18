///|
let bench_bytes : Bytes = Bytes::make(4096, b'a')

///|
test "bench bytes find miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find_byte(bench_bytes, b'Z')))
}

///|
test "bench bytes find miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_bytes.find(b"Z")))
}

///|
test "bench bytes equal (mizchi/x)" (b : @bench.T) {
  let other = Bytes::make(4096, b'a')
  b.bench(() => b.keep(equal(bench_bytes, other)))
}

///|
test "bench bytes equal (builtin)" (b : @bench.T) {
  let other = Bytes::make(4096, b'a')
  b.bench(() => b.keep(bench_bytes == other))
}
