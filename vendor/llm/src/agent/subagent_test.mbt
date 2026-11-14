///|
test "subagent queue spawns and returns success result" {
  let queue = SubagentQueue::new(fn(task) { Ok("done:" + task) })
  let status = queue.spawn(
    "collect logs",
    label=Some("logs"),
    origin_channel="telegram",
    origin_chat_id="42",
  )
  assert_true(status.contains("started"))
  assert_eq(queue.pending_count(), 1)
  let next = queue.run_next()
  match next {
    Some(result) => {
      assert_true(result.ok)
      assert_eq(result.task.id, "sub-1")
      assert_eq(result.task.origin_channel, "telegram")
      assert_eq(result.task.origin_chat_id, "42")
      assert_true(result.announcement.contains("collect logs"))
      assert_true(result.announcement.contains("done:collect logs"))
    }
    None => assert_true(false)
  }
  assert_eq(queue.pending_count(), 0)
}

///|
test "subagent queue returns failure result" {
  let queue = SubagentQueue::new(fn(_task) { Err("boom") })
  ignore(queue.spawn("task-x"))
  let next = queue.run_next()
  match next {
    Some(result) => {
      assert_false(result.ok)
      assert_eq(result.result, "Error: boom")
      assert_true(result.announcement.contains("failed"))
      assert_true(result.announcement.contains("boom"))
    }
    None => assert_true(false)
  }
}
