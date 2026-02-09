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

///|
test "normalize_planned_file_path converts absolute path under work_dir" {
  let got = normalize_planned_file_path(
    "/tmp/bit-orch-debug/src/a.txt", "/tmp/bit-orch-debug",
  )
  assert_eq(got, Some("src/a.txt"))
}

///|
test "normalize_planned_file_path rejects absolute path outside work_dir" {
  let got = normalize_planned_file_path("/etc/passwd", "/tmp/bit-orch-debug")
  assert_eq(got, None)
}

///|
test "normalize_subtask_plans unifies absolute/relative path for overlap check" {
  let plans : Array[SubtaskPlan] = [
    { task: "edit a", files: ["/tmp/bit-orch-debug/src/a.txt"] },
    { task: "edit a again", files: ["src/a.txt"] },
  ]
  let normalized = normalize_subtask_plans(plans, "/tmp/bit-orch-debug", fn(
    _s,
  ) {

  })
  let conflicts = validate_file_overlap(normalized)
  assert_eq(conflicts, ["src/a.txt (subtask 0 and 1)"])
}

///|
test "select_bit_binary prefers BIT_PATH env" {
  let got = select_bit_binary(
    "/custom/bit", "/tmp/_build/bit_cli.exe", "/usr/local/bin/bit",
  )
  assert_eq(got, "/custom/bit")
}

///|
test "select_bit_binary prefers argv0 when it is a bit binary" {
  let got = select_bit_binary(
    "", "/tmp/_build/native/release/build/bit_cli/bit_cli.exe", "/usr/local/bin/bit",
  )
  assert_eq(got, "/tmp/_build/native/release/build/bit_cli/bit_cli.exe")
}

///|
test "select_bit_binary falls back to which bit for non-bit argv0" {
  let got = select_bit_binary("", "moon", "/usr/local/bin/bit")
  assert_eq(got, "/usr/local/bin/bit")
}
