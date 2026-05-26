///| Tests for trailer parsing and manipulation

///|
test "parse_trailers: message with Signed-off-by" {
  let msg = "Fix bug\n\nSigned-off-by: A <a@b>\n"
  let trailers = parse_trailers(msg)
  assert_eq(trailers.length(), 1)
  assert_eq(trailers[0].0, "Signed-off-by")
  assert_eq(trailers[0].1, "A <a@b>")
}

///|
test "parse_trailers: multiple trailers" {
  let msg = "Subject\n\nSigned-off-by: A <a@b>\nReviewed-by: B <b@c>\n"
  let trailers = parse_trailers(msg)
  assert_eq(trailers.length(), 2)
  assert_eq(trailers[0].0, "Signed-off-by")
  assert_eq(trailers[1].0, "Reviewed-by")
}

///|
test "parse_trailers: no trailers" {
  let msg = "Just a subject\n\nSome body text.\n"
  let trailers = parse_trailers(msg)
  assert_eq(trailers.length(), 0)
}

///|
test "add_trailer: message without trailers" {
  let msg = "Fix bug\n"
  let result = add_trailer(msg, "Signed-off-by", "A <a@b>")
  assert_true(result.contains("Signed-off-by: A <a@b>"))
  // Should have blank line before trailer
  assert_true(result.contains("\n\nSigned-off-by"))
}

///|
test "add_trailer: message with existing trailers" {
  let msg = "Fix bug\n\nSigned-off-by: A <a@b>\n"
  let result = add_trailer(msg, "Reviewed-by", "B <b@c>")
  assert_true(result.contains("Signed-off-by: A <a@b>"))
  assert_true(result.contains("Reviewed-by: B <b@c>"))
}

///|
test "add_trailer: preserves body" {
  let msg = "Subject line\n\nBody paragraph.\n"
  let result = add_trailer(msg, "Co-authored-by", "X <x@y>")
  assert_true(result.has_prefix("Subject line\n"))
  assert_true(result.contains("Body paragraph."))
  assert_true(result.contains("Co-authored-by: X <x@y>"))
}
