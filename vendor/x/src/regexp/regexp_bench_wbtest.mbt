// Microbenchmarks comparing `mizchi/x/regexp` against the upstream
// `moonbitlang/regexp` engine. The interesting comparison is on the JS target
// (`moon bench --target js`): there `mizchi/x/regexp` drives the host `RegExp`
// through FFI, while `@upstream` runs the pure-MoonBit VM. On native both sit on
// the same engine, so the numbers should be roughly equal (the wrapper cost).

///|
// A pattern with two capture groups, and an input where the match only appears
// at the very end so the engine has to scan a long no-match prefix first.
let bench_pattern : String = "([a-z]+)=([0-9]+)"

///|
fn bench_input() -> String {
  let sb = StringBuilder()
  for _ in 0..<20 {
    sb.write_string("lorem ipsum dolor sit amet ")
  }
  sb.write_string("key=12345 end")
  sb.to_string()
}

///|
test "bench regexp compile (mizchi/x)" (b : @bench.T) {
  b.bench(() => b.keep(compile(bench_pattern)) catch { _ => () })
}

///|
test "bench regexp compile (upstream)" (b : @bench.T) {
  b.bench(() => b.keep(@upstream.compile(bench_pattern)) catch { _ => () })
}

///|
test "bench regexp execute (mizchi/x)" (b : @bench.T) {
  let re = compile(bench_pattern)
  let input = bench_input()
  b.bench(() => b.keep(re.execute(input).matched()))
}

///|
test "bench regexp execute (upstream)" (b : @bench.T) {
  let re = @upstream.compile(bench_pattern)
  let input = bench_input()
  b.bench(() => b.keep(re.execute(input).matched()))
}

///|
test "bench regexp execute + capture (mizchi/x)" (b : @bench.T) {
  let re = compile(bench_pattern)
  let input = bench_input()
  b.bench(() => {
    let result = re.execute(input)
    b.keep(result.get(1))
    b.keep(result.get(2))
  })
}

///|
test "bench regexp execute + capture (upstream)" (b : @bench.T) {
  let re = @upstream.compile(bench_pattern)
  let input = bench_input()
  b.bench(() => {
    let result = re.execute(input)
    b.keep(result.get(1))
    b.keep(result.get(2))
  })
}
