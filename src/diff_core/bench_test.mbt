///| Benchmarks for the low-level diff primitives (Myers, line split).
///
/// Run with:
///   moon bench -p mizchi/bit/diff_core --target native -f bench_test.mbt
///
/// Hot in every `diff`, `log -p`, `apply`, and merge.

///|
fn bench_make_lines(count : Int) -> Array[String] {
  let lines : Array[String] = []
  for i in 0..<count {
    lines.push("line \{i}: lorem ipsum dolor sit amet, consectetur adipiscing")
  }
  lines
}

///|
fn bench_mutate_lines(base : Array[String], change_pct : Int) -> Array[String] {
  let out : Array[String] = []
  for i, line in base {
    if i % 100 < change_pct {
      out.push(line + " [edited]")
    } else {
      out.push(line)
    }
  }
  out
}

///|
let bench_lines_a_100 : Array[String] = bench_make_lines(100)

///|
let bench_lines_b_100_10pct : Array[String] = bench_mutate_lines(
  bench_lines_a_100, 10,
)

///|
let bench_lines_a_1000 : Array[String] = bench_make_lines(1000)

///|
let bench_lines_b_1000_10pct : Array[String] = bench_mutate_lines(
  bench_lines_a_1000, 10,
)

///|
let bench_blob_text_100kb : Bytes = {
  let sb = StringBuilder::new()
  for i in 0..<2500 {
    sb.write_string("line \{i}: forty-byte template ABCDEFGHIJ\n")
  }
  // String → Bytes (UTF-8 ASCII so length matches).
  let s = sb.to_string()
  Bytes::makei(s.length(), fn(i) {
    s.unsafe_get(i).to_int().to_byte()
  })
}

///|
test "bench split_lines 100 KiB" (b : @bench.T) {
  b.bench(fn() {
    let lines = split_lines(bench_blob_text_100kb)
    b.keep(lines.length())
  })
}

///|
test "bench count_lines 100 KiB" (b : @bench.T) {
  b.bench(fn() {
    let n = count_lines(bench_blob_text_100kb)
    b.keep(n)
  })
}

///|
test "bench myers_diff identical 100 lines" (b : @bench.T) {
  b.bench(fn() {
    let ops = myers_diff(bench_lines_a_100, bench_lines_a_100)
    b.keep(ops.length())
  })
}

///|
test "bench myers_diff 10pct changed 100 lines" (b : @bench.T) {
  b.bench(fn() {
    let ops = myers_diff(bench_lines_a_100, bench_lines_b_100_10pct)
    b.keep(ops.length())
  })
}

///|
test "bench myers_diff identical 1000 lines" (b : @bench.T) {
  b.bench(fn() {
    let ops = myers_diff(bench_lines_a_1000, bench_lines_a_1000)
    b.keep(ops.length())
  })
}

///|
test "bench myers_diff 10pct changed 1000 lines" (b : @bench.T) {
  b.bench(fn() {
    let ops = myers_diff(bench_lines_a_1000, bench_lines_b_1000_10pct)
    b.keep(ops.length())
  })
}
