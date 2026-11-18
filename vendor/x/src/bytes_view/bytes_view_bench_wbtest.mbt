///|
let bench_backing : Bytes = Bytes::make(4098, b'a')

///|
let bench_view : BytesView = bench_backing[1:4097]

///|
test "bench BytesView find byte miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find_byte(bench_view, b'Z')))
}

///|
test "bench BytesView find byte miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.find(b"Z"[:])))
}

///|
test "bench BytesView equal (mizchi/x)" (b : @bench.T) {
  let other = Bytes::make(4096, b'a')[:]
  b.bench(() => b.keep(equal(bench_view, other)))
}

///|
test "bench BytesView equal (builtin)" (b : @bench.T) {
  let other = Bytes::make(4096, b'a')[:]
  b.bench(() => b.keep(bench_view == other))
}

///|
test "bench BytesView reverse find byte miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(rev_find_byte(bench_view, b'Z')))
}

///|
test "bench BytesView reverse find byte miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.rev_find(b"Z"[:])))
}

///|
test "bench BytesView find sequence miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find(bench_view, b"ZZ"[:])))
}

///|
test "bench BytesView find sequence miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.find(b"ZZ"[:])))
}

///|
test "bench BytesView non-ASCII miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find_non_ascii(bench_view)))
}

///|
test "bench BytesView non-ASCII miss (scalar)" (b : @bench.T) {
  b.bench(fn() {
    let mut found = None
    for i in 0..<bench_view.length() {
      if bench_view.unsafe_get(i).to_int() >= 0x80 {
        found = Some(i)
        break
      }
    }
    b.keep(found)
  })
}

///|
test "bench BytesView compare late difference (mizchi/x)" (b : @bench.T) {
  let other = Bytes::makei(4096, i => if i == 4095 { b'b' } else { b'a' })[:]
  b.bench(() => b.keep(compare(bench_view, other)))
}

///|
test "bench BytesView compare late difference (builtin)" (b : @bench.T) {
  let other = Bytes::makei(4096, i => if i == 4095 { b'b' } else { b'a' })[:]
  b.bench(() => b.keep(bench_view.compare(other)))
}
