///| Tests for fast-import stream parsing functions.

///|
test "fast_import_parse_data: byte-count mode" {
  let lines = ["data 5", "hello"]
  let result = fast_import_parse_data(lines, 0)
  let content = result.content
  @test.assert_eq(content.length(), 5)
  @test.assert_eq(content[0], b'h')
  @test.assert_eq(content[1], b'e')
  @test.assert_eq(content[2], b'l')
  @test.assert_eq(content[3], b'l')
  @test.assert_eq(content[4], b'o')
  @test.assert_eq(result.next_line, 2)
}

///|
test "fast_import_parse_data: byte-count mode with newline in data" {
  // "data 11\nhello\nworld" — 11 bytes: "hello\nworld"
  let lines = ["data 11", "hello", "world"]
  let result = fast_import_parse_data(lines, 0)
  let content = result.content
  @test.assert_eq(content.length(), 11)
  // "hello\nworld"
  @test.assert_eq(content[5], b'\n')
  @test.assert_eq(content[6], b'w')
  @test.assert_eq(result.next_line, 3)
}

///|
test "fast_import_parse_data: byte-count zero" {
  let lines = ["data 0"]
  let result = fast_import_parse_data(lines, 0)
  @test.assert_eq(result.content.length(), 0)
  @test.assert_eq(result.next_line, 1)
}

///|
test "fast_import_parse_data: delimited mode" {
  let lines = ["data <<EOF", "hello", "world", "EOF"]
  let result = fast_import_parse_data(lines, 0)
  let content = result.content
  // "hello\nworld"
  @test.assert_eq(content.length(), 11)
  @test.assert_eq(content[0], b'h')
  @test.assert_eq(content[5], b'\n')
  @test.assert_eq(content[6], b'w')
  @test.assert_eq(result.next_line, 4)
}

///|
test "fast_import_parse_data: delimited mode empty" {
  let lines = ["data <<EOF", "EOF"]
  let result = fast_import_parse_data(lines, 0)
  @test.assert_eq(result.content.length(), 0)
  @test.assert_eq(result.next_line, 2)
}

///|
test "fast_import_parse_data: not a data line" {
  let lines = ["blob"]
  let result = fast_import_parse_data(lines, 0)
  @test.assert_eq(result.content.length(), 0)
  @test.assert_eq(result.next_line, 1)
}

///|
test "fast_import_parse_data: trailing blank line consumed" {
  let lines = ["data 5", "hello", "", "next"]
  let result = fast_import_parse_data(lines, 0)
  @test.assert_eq(result.content.length(), 5)
  // Should consume trailing blank line
  @test.assert_eq(result.next_line, 3)
}

///|
test "fast_import_parse_ident: full author line" {
  let result = fast_import_parse_ident(
    "Test User <test@example.com> 1000 +0000",
  )
  assert_true(result is Some(_))
  let id = result.unwrap()
  @test.assert_eq(id.ident, "Test User <test@example.com>")
  @test.assert_eq(id.timestamp, 1000L)
  @test.assert_eq(id.tz, "+0000")
}

///|
test "fast_import_parse_ident: negative timezone" {
  let result = fast_import_parse_ident(
    "Author Name <author@example.com> 1700000000 -0500",
  )
  assert_true(result is Some(_))
  let id = result.unwrap()
  @test.assert_eq(id.ident, "Author Name <author@example.com>")
  @test.assert_eq(id.timestamp, 1700000000L)
  @test.assert_eq(id.tz, "-0500")
}

///|
test "fast_import_parse_ident: timestamp only no tz" {
  let result = fast_import_parse_ident("Name <email> 42")
  assert_true(result is Some(_))
  let id = result.unwrap()
  @test.assert_eq(id.ident, "Name <email>")
  @test.assert_eq(id.timestamp, 42L)
  @test.assert_eq(id.tz, "+0000")
}

///|
test "fast_import_parse_ident: no angle bracket" {
  let result = fast_import_parse_ident("no brackets here")
  assert_true(result is None)
}

///|
test "fast_import_parse_file_op: modify" {
  let result = fast_import_parse_file_op("M 100644 :1 path/file.txt")
  @test.assert_eq(
    result,
    Some(
      FastImportFileOp::Modify(
        mode="100644",
        dataref=":1",
        path="path/file.txt",
      ),
    ),
  )
}

///|
test "fast_import_parse_file_op: modify with hex sha" {
  let result = fast_import_parse_file_op(
    "M 100755 da39a3ee5e6b4b0d3255bfef95601890afd80709 script.sh",
  )
  @test.assert_eq(
    result,
    Some(
      FastImportFileOp::Modify(
        mode="100755",
        dataref="da39a3ee5e6b4b0d3255bfef95601890afd80709",
        path="script.sh",
      ),
    ),
  )
}

///|
test "fast_import_parse_file_op: modify inline" {
  let result = fast_import_parse_file_op("M 100644 inline README.md")
  @test.assert_eq(
    result,
    Some(
      FastImportFileOp::Modify(
        mode="100644",
        dataref="inline",
        path="README.md",
      ),
    ),
  )
}

///|
test "fast_import_parse_file_op: delete" {
  let result = fast_import_parse_file_op("D path.txt")
  @test.assert_eq(result, Some(FastImportFileOp::Delete(path="path.txt")))
}

///|
test "fast_import_parse_file_op: deleteall" {
  let result = fast_import_parse_file_op("deleteall")
  @test.assert_eq(result, Some(FastImportFileOp::DeleteAll))
}

///|
test "fast_import_parse_file_op: rename" {
  let result = fast_import_parse_file_op("R old/path.txt new/path.txt")
  @test.assert_eq(
    result,
    Some(
      FastImportFileOp::Rename(old_path="old/path.txt", new_path="new/path.txt"),
    ),
  )
}

///|
test "fast_import_parse_file_op: copy" {
  let result = fast_import_parse_file_op("C src/file.txt dst/file.txt")
  @test.assert_eq(
    result,
    Some(
      FastImportFileOp::Copy(old_path="src/file.txt", new_path="dst/file.txt"),
    ),
  )
}

///|
test "fast_import_parse_file_op: unrecognized" {
  let result = fast_import_parse_file_op("commit refs/heads/main")
  assert_true(result is None)
}

///|
test "fast_import_parse_file_op: quoted path" {
  let result = fast_import_parse_file_op("D \"path with spaces.txt\"")
  @test.assert_eq(result, Some(FastImportFileOp::Delete(path="path with spaces.txt")))
}

///|
test "fast_import_parse_dataref: mark reference" {
  let (mark, hex) = fast_import_parse_dataref(":42")
  @test.assert_eq(mark, 42)
  @test.assert_eq(hex, "")
}

///|
test "fast_import_parse_dataref: hex sha" {
  let (mark, hex) = fast_import_parse_dataref(
    "da39a3ee5e6b4b0d3255bfef95601890afd80709",
  )
  @test.assert_eq(mark, 0)
  @test.assert_eq(hex, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
}

///|
test "fast_import_parse_marks: parse marks file" {
  let content = ":1 0000000000000000000000000000000000000001\n:2 0000000000000000000000000000000000000002\n"
  let marks = fast_import_parse_marks(content)
  @test.assert_eq(marks.length(), 2)
  @test.assert_eq(marks[0].0, 1)
  @test.assert_eq(marks[0].1, "0000000000000000000000000000000000000001")
  @test.assert_eq(marks[1].0, 2)
  @test.assert_eq(marks[1].1, "0000000000000000000000000000000000000002")
}

///|
test "fast_import_parse_marks: skip invalid lines" {
  let content = "invalid line\n:0 bad\n:1 0000000000000000000000000000000000000001\n"
  let marks = fast_import_parse_marks(content)
  @test.assert_eq(marks.length(), 1)
  @test.assert_eq(marks[0].0, 1)
}

///|
test "fast_import_parse_trim: basic" {
  @test.assert_eq(fast_import_parse_trim("  hello  "), "hello")
  @test.assert_eq(fast_import_parse_trim("hello"), "hello")
  @test.assert_eq(fast_import_parse_trim("\n\thello\r\n"), "hello")
  @test.assert_eq(fast_import_parse_trim(""), "")
}

///|
test "fast_import_parse_unquote_path: unquoted" {
  @test.assert_eq(fast_import_parse_unquote_path("simple/path"), "simple/path")
}

///|
test "fast_import_parse_unquote_path: quoted" {
  @test.assert_eq(
    fast_import_parse_unquote_path("\"path/with spaces\""),
    "path/with spaces",
  )
}

///|
test "fast_import_parse_unquote_path: escape sequences" {
  @test.assert_eq(fast_import_parse_unquote_path("\"a\\nb\""), "a\nb")
  @test.assert_eq(fast_import_parse_unquote_path("\"a\\tb\""), "a\tb")
  @test.assert_eq(fast_import_parse_unquote_path("\"a\\\\b\""), "a\\b")
  @test.assert_eq(fast_import_parse_unquote_path("\"a\\\"b\""), "a\"b")
}

///|
test "fast_import_parse_split_two_paths: unquoted" {
  let result = fast_import_parse_split_two_paths("old.txt new.txt")
  @test.assert_eq(result, Some(("old.txt", "new.txt")))
}

///|
test "fast_import_parse_split_two_paths: first quoted" {
  let result = fast_import_parse_split_two_paths("\"old file.txt\" new.txt")
  @test.assert_eq(result, Some(("old file.txt", "new.txt")))
}

///|
test "fast_import_parse_split_two_paths: no space" {
  let result = fast_import_parse_split_two_paths("single")
  assert_true(result is None)
}

///|
test "fast_import_parse_string_byte_count: ascii" {
  @test.assert_eq(fast_import_parse_string_byte_count("hello"), 5)
  @test.assert_eq(fast_import_parse_string_byte_count(""), 0)
  @test.assert_eq(fast_import_parse_string_byte_count("ab cd"), 5)
}
