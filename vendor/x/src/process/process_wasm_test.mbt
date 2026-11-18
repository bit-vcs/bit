///|
async test "wasm run and cancellation use async process" {
  let code = @process.run("true", [], cancel_handler=@process.hard_cancel())
  assert_eq(code, 0)
}

///|
async test "wasm collect output uses async process pipes" {
  let (code, stdout, stderr) = @process.collect_output("sh", [
    "-c", "printf output; printf error >&2",
  ])
  assert_eq(code, 0)
  assert_eq(stdout.text(), "output")
  assert_eq(stderr.text(), "error")
}

///|
async test "wasm spawn preserves ordinary process options" {
  @async.with_task_group(group => {
    let process = @process.spawn(
      group,
      "true",
      [],
      cancel_handler=@process.graceful_cancel(timeout=10),
    )
    assert_eq(process.wait(), 0)
  })
}

///|
async test "wasm file redirects use async process" {
  let path = "mizchi_x_process_wasm_redirect_test.txt"
  @process.run(
    "sh",
    ["-c", "printf redirected"],
    stdout=@process.redirect_to_file(path, create_mode=CreateOrTruncate),
  )
  |> ignore
  assert_eq(@fs.read_file(path).text(), "redirected")
  @fs.remove(path)
}
