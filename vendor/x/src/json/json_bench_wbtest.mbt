// Microbenchmarks comparing `mizchi/x/json` against the upstream
// `moonbitlang/core/json`. The interesting comparison is on the JS target
// (`moon bench --target js`): there `mizchi/x/json` calls the host
// `JSON.parse` / `JSON.stringify` and converts to/from the builtin `Json`,
// while `@upstream` runs the pure-MoonBit parser/serializer. On native both sit
// on the same engine, so the numbers should be roughly equal (the wrapper cost).

///|
// A moderately sized document: an array of 50 small objects mixing strings,
// integers, floats and booleans.
fn bench_json() -> String {
  let sb = StringBuilder()
  sb.write_string("[")
  for i in 0..<50 {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string("{\"id\":")
    sb.write_object(i)
    sb.write_string(",\"name\":\"item_")
    sb.write_object(i)
    sb.write_string("\",\"active\":")
    sb.write_string(if i % 2 == 0 { "true" } else { "false" })
    sb.write_string(",\"score\":3.14159,\"tags\":[\"a\",\"b\",\"c\"]}")
  }
  sb.write_string("]")
  sb.to_string()
}

///|
test "bench json parse (mizchi/x)" (b : @bench.T) {
  let src = bench_json()
  b.bench(() => b.keep(parse(src)) catch { _ => () })
}

///|
test "bench json parse (upstream)" (b : @bench.T) {
  let src = bench_json()
  b.bench(() => b.keep(@upstream.parse(src)) catch { _ => () })
}

///|
test "bench json stringify (mizchi/x)" (b : @bench.T) {
  let value = parse(bench_json())
  b.bench(() => b.keep(stringify(value)))
}

///|
test "bench json stringify (upstream)" (b : @bench.T) {
  let value = @upstream.parse(bench_json())
  b.bench(() => b.keep(value.stringify()))
}

///|
test "bench json valid (mizchi/x)" (b : @bench.T) {
  let src = bench_json()
  b.bench(() => b.keep(valid(src)))
}

///|
test "bench json valid (upstream)" (b : @bench.T) {
  let src = bench_json()
  b.bench(() => b.keep(@upstream.valid(src)))
}
