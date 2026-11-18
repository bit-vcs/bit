///|
let bench_string : String = String::make(4098, 'a')

///|
let bench_view : StringView = bench_string[1:4097]

///|
test "bench StringView find code unit miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find_code_unit(bench_view, ('Z' : UInt16))))
}

///|
test "bench StringView find code unit miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.find("Z"[:])))
}

///|
test "bench StringView reverse find code unit miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(rev_find_code_unit(bench_view, ('Z' : UInt16))))
}

///|
test "bench StringView reverse find code unit miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.rev_find("Z"[:])))
}

///|
test "bench StringView find substring miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(find(bench_view, "ZZ"[:])))
}

///|
test "bench StringView find substring miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.find("ZZ"[:])))
}

///|
test "bench StringView reverse find substring miss (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(rev_find(bench_view, "ZZ"[:])))
}

///|
test "bench StringView reverse find substring miss (builtin)" (b : @bench.T) {
  b.bench(() => b.keep(bench_view.rev_find("ZZ"[:])))
}

///|
test "bench StringView compare (mizchi/x)" (b : @bench.T) {
  let other = String::make(4095, 'a') + "b"
  b.bench(() => b.keep(compare(bench_view, other[:])))
}

///|
test "bench StringView compare (builtin)" (b : @bench.T) {
  let other = String::make(4095, 'a') + "b"
  b.bench(() => b.keep(bench_view.compare(other[:])))
}
