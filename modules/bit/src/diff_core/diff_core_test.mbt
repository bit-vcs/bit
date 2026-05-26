///|
test "myers_diff identical" {
  let old = ["a", "b", "c"]
  let new_ = ["a", "b", "c"]
  let edits = @diff_core.myers_diff(old, new_)
  assert_eq(edits.length(), 3)
  // All should be Keep
  for edit in edits {
    assert_true(edit is @diff_core.DiffEditOp::Keep(_, _))
  }
}

///|
test "myers_diff empty inputs" {
  let edits = @diff_core.myers_diff([], [])
  assert_eq(edits.length(), 0)
  let inserts = @diff_core.myers_diff([], ["a", "b"])
  assert_eq(inserts.length(), 2)
  for edit in inserts {
    assert_true(edit is @diff_core.DiffEditOp::Insert(_))
  }
  let deletes = @diff_core.myers_diff(["a", "b"], [])
  assert_eq(deletes.length(), 2)
  for edit in deletes {
    assert_true(edit is @diff_core.DiffEditOp::Delete(_))
  }
}

///|
test "myers_diff simple change" {
  let old = ["a", "b", "c"]
  let new_ = ["a", "x", "c"]
  let edits = @diff_core.myers_diff(old, new_)
  let mut deletes = 0
  let mut inserts = 0
  let mut keeps = 0
  for edit in edits {
    match edit {
      @diff_core.DiffEditOp::Keep(_, _) => keeps += 1
      @diff_core.DiffEditOp::Delete(_) => deletes += 1
      @diff_core.DiffEditOp::Insert(_) => inserts += 1
    }
  }
  assert_eq(keeps, 2)
  assert_eq(deletes, 1)
  assert_eq(inserts, 1)
}

///|
test "split_lines" {
  let data = b"line1\nline2\nline3\n"
  let lines = @diff_core.split_lines(data)
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "line1")
  assert_eq(lines[1], "line2")
  assert_eq(lines[2], "line3")
  // No trailing newline -> no empty trailing element
  let data2 = b"a\nb"
  let lines2 = @diff_core.split_lines(data2)
  assert_eq(lines2.length(), 2)
  assert_eq(lines2[0], "a")
  assert_eq(lines2[1], "b")
}

///|
test "count_lines" {
  assert_eq(@diff_core.count_lines(b"hello\nworld\n"), 2)
  assert_eq(@diff_core.count_lines(b"hello\nworld"), 2)
  assert_eq(@diff_core.count_lines(b"hello"), 1)
  assert_eq(@diff_core.count_lines(b""), 0)
}

///|
test "unified_hunks basic" {
  let old_content : Bytes = b"line1\nline2\nline3\n"
  let new_content : Bytes = b"line1\nmodified\nline3\n"
  let out : Array[String] = []
  @diff_core.unified_hunks(out, Some(old_content), Some(new_content))
  assert_true(out.length() > 0)
  // Should contain hunk header
  assert_true(out[0].has_prefix("@@"))
  // Should contain the diff
  let joined = out.join("\n")
  assert_true(joined.contains("-line2"))
  assert_true(joined.contains("+modified"))
}
