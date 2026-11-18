///|
let bench_backing : FixedArray[Byte] = FixedArray::make(4098, b'a')

///|
let bench_view : ArrayView[Byte] = bench_backing[1:4097]

///|
test "bench ArrayView find byte miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find_byte(bench_view, b'Z')))
}

///|
test "bench ArrayView find byte miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.search(b'Z')))
}

///|
test "bench ArrayView reverse find byte miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(rev_find_byte(bench_view, b'Z')))
}

///|
test "bench ArrayView reverse find byte miss (scalar)" (b : @bench.T) {
  b.bench(fn() {
    let mut found = None
    let mut i = bench_view.length() - 1
    while i >= 0 {
      if bench_view[i] == b'Z' {
        found = Some(i)
        break
      }
      i = i - 1
    }
    b.keep(found)
  })
}

///|
test "bench ArrayView find sequence miss (mizchi/x)" (b : @bench.T) {
  let needle : FixedArray[Byte] = [b'Z', b'Z']
  b.bench(() => b.keep(find(bench_view, needle[:])))
}

///|
test "bench ArrayView find sequence miss (scalar)" (b : @bench.T) {
  b.bench(fn() {
    let mut found = None
    for i in 0..<(bench_view.length() - 1) {
      if bench_view[i] == b'Z' && bench_view[i + 1] == b'Z' {
        found = Some(i)
        break
      }
    }
    b.keep(found)
  })
}

///|
test "bench ArrayView reverse find sequence miss (mizchi/x)" (b : @bench.T) {
  let needle : FixedArray[Byte] = [b'Z', b'Z']
  b.bench(() => b.keep(rev_find(bench_view, needle[:])))
}

///|
test "bench ArrayView reverse find sequence miss (scalar)" (b : @bench.T) {
  b.bench(fn() {
    let mut found = None
    let mut i = bench_view.length() - 2
    while i >= 0 {
      if bench_view[i] == b'Z' && bench_view[i + 1] == b'Z' {
        found = Some(i)
        break
      }
      i = i - 1
    }
    b.keep(found)
  })
}
