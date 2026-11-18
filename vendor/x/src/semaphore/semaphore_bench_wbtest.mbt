// Microbenchmarks for the sync surface of mizchi/x/semaphore.
//
// `acquire` is async; `try_acquire` + `release` form the hot sync loop
// we want to measure. Construction cost is covered separately.

///|
test "bench semaphore Semaphore::new (size=1)" (b : @bench.T) {
  b.bench(fn() { b.keep(Semaphore(1)) })
}

///|
test "bench semaphore Semaphore::new (size=64)" (b : @bench.T) {
  b.bench(fn() { b.keep(Semaphore(64)) })
}

///|
test "bench semaphore try_acquire + release (uncontended)" (b : @bench.T) {
  let sem = Semaphore(1)
  b.bench(fn() {
    let _ = sem.try_acquire()
    sem.release()
    b.keep(sem)
  })
}
