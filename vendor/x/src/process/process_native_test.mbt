///|
async test "run returns exit code" {
  let code = @process.run("true", [])
  assert_eq(code, 0)
}

///|
async test "run non-zero exit" {
  let code = @process.run("false", [])
  assert_true(code != 0)
}

///|
async test "collect_output" {
  let (exit_code, stdout, _stderr) = @process.collect_output("echo", ["hello"])
  assert_eq(exit_code, 0)
  assert_eq(stdout.text().trim_end(), "hello")
}

///|
async test "kill sends signal to direct child" {
  // Even without process-group semantics, `@process.kill(pid, ...)`
  // hits the immediate child. Use `sleep` so we have a deterministic
  // long-running target.
  @async.with_task_group(group => {
    let proc = @process.spawn(group, "bash", ["-c", "sleep 30"], no_wait=true)
    @async.sleep(50)
    @process.kill(proc.pid, @signal.SIGTERM)
    @async.sleep(150)
    try proc.try_wait() catch {
      _ => assert_true(false)
    } noraise {
      Some(_) => ()
      None => assert_true(false)
    }
  })
}
