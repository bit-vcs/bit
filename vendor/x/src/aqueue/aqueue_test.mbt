///|
async test "queue put get" {
  let q : @aqueue.Queue[Int32] = @aqueue.Queue(kind=@aqueue.Unbounded)
  q.put(1)
  inspect(q.get(), content="1")
}

///|
test "queue try put get" {
  let q : @aqueue.Queue[String] = @aqueue.Queue(kind=@aqueue.Blocking(1))
  assert_true(q.try_put("a"))
  assert_true(!q.try_put("b"))
  match q.try_get() {
    Some(value) => inspect(value, content="a")
    None => fail("expected queued value")
  }
}
