// Microbenchmarks for the sync surface of mizchi/x/cond_var.
//
// `wait` is async and out of scope for `@bench.T`. `signal` / `broadcast`
// without a waiter are still meaningful: they exercise the same path
// the wrapper uses when a notifier races a waiter.

///|
test "bench cond_var Cond::new" (b : @bench.T) {
  b.bench(fn() { b.keep(Cond()) })
}

///|
test "bench cond_var signal (no waiter)" (b : @bench.T) {
  let cond = Cond()
  b.bench(fn() {
    cond.signal()
    b.keep(cond)
  })
}

///|
test "bench cond_var broadcast (no waiter)" (b : @bench.T) {
  let cond = Cond()
  b.bench(fn() {
    cond.broadcast()
    b.keep(cond)
  })
}
