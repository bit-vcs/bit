// Microbenchmarks for the sync-only surface of mizchi/x/aqueue.
//
// `Queue::get` / `Queue::put` are async and can't be wrapped in `@bench.T`
// directly, so we cover the sync siblings (`try_put` / `try_get`) plus
// the construction cost. Together they expose how thin (or not) the
// mizchi/x wrapper sits on top of the upstream `moonbitlang/core/async/aqueue`.

///|
test "bench aqueue Queue::new (Unbounded)" (b : @bench.T) {
  b.bench(() => {
    let q : Queue[Int32] = Queue(kind=Unbounded)
    b.keep(q)
  })
}

///|
test "bench aqueue Queue::new (Blocking 64)" (b : @bench.T) {
  b.bench(() => {
    let q : Queue[Int32] = Queue(kind=Blocking(64))
    b.keep(q)
  })
}

///|
test "bench aqueue try_put + try_get roundtrip (Unbounded)" (b : @bench.T) {
  let q : Queue[Int32] = Queue(kind=Unbounded)
  b.bench(() => {
    try {
      let _ = q.try_put(1)
      b.keep(q.try_get())
    } catch {
      _ => ()
    }
  })
}

///|
test "bench aqueue try_put + try_get roundtrip (Blocking 64)" (b : @bench.T) {
  let q : Queue[Int32] = Queue(kind=Blocking(64))
  b.bench(() => {
    try {
      let _ = q.try_put(1)
      b.keep(q.try_get())
    } catch {
      _ => ()
    }
  })
}
