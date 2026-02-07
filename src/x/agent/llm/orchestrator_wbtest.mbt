///| Tests for orchestrator command failure handling

///|
test "exec_checked returns none and logs on command error" {
  let logs = StringBuilder::new()
  let result = exec_checked(
    "dummy",
    "worktree add",
    fn(_cmd) { "ERROR: exit code 1: boom" },
    fn(s) { logs.write_string(s + "\n") },
  )
  assert_true(result is None)
  let out = logs.to_string()
  assert_true(out.contains("worktree add"))
  assert_true(out.contains("ERROR: exit code 1"))
}

///|
test "exec_checked returns output on success" {
  let result = exec_checked("dummy", "status", fn(_cmd) { "ok\n" }, fn(_s) {  })
  assert_eq(result, Some("ok\n"))
}
