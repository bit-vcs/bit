///| Tests for fast-import stream parsing functions.

///|
test "fast_import_parse_data: byte-count mode" {
  let lines = ["data 5", "hello"]
  let result = fast_import_parse_data(lines, 0)
  let content = result.content
  assert_eq(content.length(), 5)
  assert_eq(content[0], b'h')
  assert_eq(content[1], b'e')
  assert_eq(content[2], b'l')
  assert_eq(content[3], b'l')
  assert_eq(content[4], b'o')
  assert_eq(result.next_line, 2)
}

///|
test "fast_import_parse_data: byte-count mode with newline in data" {
  // "data 11\nhello\nworld" — 11 bytes: "hello\nworld"
  let lines = ["data 11", "hello", "world"]
  let result = fast_import_parse_data(lines, 0)
  let content = result.content
  assert_eq(content.length(), 11)
  // "hello\nworld"
  assert_eq(content[5], b'\n')
  assert_eq(content[6], b'w')
  assert_eq(result.next_line, 3)
}

///|
test "fast_import_parse_data: byte-count zero" {
  let lines = ["data 0"]
  let result = fast_import_parse_data(lines, 0)
  assert_eq(result.content.length(), 0)
  assert_eq(result.next_line, 1)
}

///|
test "fast_import_parse_data: delimited mode" {
  let lines = ["data <<EOF", "hello", "world", "EOF"]
  let result = fast_import_parse_data(lines, 0)
  let content = result.content
  // "hello\nworld"
  assert_eq(content.length(), 11)
  assert_eq(content[0], b'h')
  assert_eq(content[5], b'\n')
  assert_eq(content[6], b'w')
  assert_eq(result.next_line, 4)
}

///|
test "fast_import_parse_data: delimited mode empty" {
  let lines = ["data <<EOF", "EOF"]
  let result = fast_import_parse_data(lines, 0)
  assert_eq(result.content.length(), 0)
  assert_eq(result.next_line, 2)
}

///|
test "fast_import_parse_data: not a data line" {
  let lines = ["blob"]
  let result = fast_import_parse_data(lines, 0)
  assert_eq(result.content.length(), 0)
  assert_eq(result.next_line, 1)
}

///|
test "fast_import_parse_data: trailing blank line consumed" {
  let lines = ["data 5", "hello", "", "next"]
  let result = fast_import_parse_data(lines, 0)
  assert_eq(result.content.length(), 5)
  // Should consume trailing blank line
  assert_eq(result.next_line, 3)
}

///|
test "fast_import_parse_ident: full author line" {
  let result = fast_import_parse_ident(
    "Test User <test@example.com> 1000 +0000",
  )
  assert_true(result is Some(_))
  let id = result.unwrap()
  assert_eq(id.ident, "Test User <test@example.com>")
  assert_eq(id.timestamp, 1000L)
  assert_eq(id.tz, "+0000")
}

///|
test "fast_import_parse_ident: negative timezone" {
  let result = fast_import_parse_ident(
    "Author Name <author@example.com> 1700000000 -0500",
  )
  assert_true(result is Some(_))
  let id = result.unwrap()
  assert_eq(id.ident, "Author Name <author@example.com>")
  assert_eq(id.timestamp, 1700000000L)
  assert_eq(id.tz, "-0500")
}

///|
test "fast_import_parse_ident: timestamp only no tz" {
  let result = fast_import_parse_ident("Name <email> 42")
  assert_true(result is Some(_))
  let id = result.unwrap()
  assert_eq(id.ident, "Name <email>")
  assert_eq(id.timestamp, 42L)
  assert_eq(id.tz, "+0000")
}

///|
test "fast_import_parse_ident: no angle bracket" {
  let result = fast_import_parse_ident("no brackets here")
  assert_true(result is None)
}

///|
test "fast_import_parse_file_op: modify" {
  let result = fast_import_parse_file_op("M 100644 :1 path/file.txt")
  assert_eq(
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
  assert_eq(
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
  assert_eq(
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
  assert_eq(result, Some(FastImportFileOp::Delete(path="path.txt")))
}

///|
test "fast_import_parse_file_op: deleteall" {
  let result = fast_import_parse_file_op("deleteall")
  assert_eq(result, Some(FastImportFileOp::DeleteAll))
}

///|
test "fast_import_parse_file_op: rename" {
  let result = fast_import_parse_file_op("R old/path.txt new/path.txt")
  assert_eq(
    result,
    Some(
      FastImportFileOp::Rename(old_path="old/path.txt", new_path="new/path.txt"),
    ),
  )
}

///|
test "fast_import_parse_file_op: copy" {
  let result = fast_import_parse_file_op("C src/file.txt dst/file.txt")
  assert_eq(
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
  assert_eq(result, Some(FastImportFileOp::Delete(path="path with spaces.txt")))
}

///|
test "fast_import_parse_dataref: mark reference" {
  let (mark, hex) = fast_import_parse_dataref(":42")
  assert_eq(mark, 42)
  assert_eq(hex, "")
}

///|
test "fast_import_parse_dataref: hex sha" {
  let (mark, hex) = fast_import_parse_dataref(
    "da39a3ee5e6b4b0d3255bfef95601890afd80709",
  )
  assert_eq(mark, 0)
  assert_eq(hex, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
}

///|
test "fast_import_parse_marks: parse marks file" {
  let content = ":1 0000000000000000000000000000000000000001\n:2 0000000000000000000000000000000000000002\n"
  let marks = fast_import_parse_marks(content)
  assert_eq(marks.length(), 2)
  assert_eq(marks[0].0, 1)
  assert_eq(marks[0].1, "0000000000000000000000000000000000000001")
  assert_eq(marks[1].0, 2)
  assert_eq(marks[1].1, "0000000000000000000000000000000000000002")
}

///|
test "fast_import_parse_marks: skip invalid lines" {
  let content = "invalid line\n:0 bad\n:1 0000000000000000000000000000000000000001\n"
  let marks = fast_import_parse_marks(content)
  assert_eq(marks.length(), 1)
  assert_eq(marks[0].0, 1)
}

///|
test "fast_import_parse_trim: basic" {
  assert_eq(fast_import_parse_trim("  hello  "), "hello")
  assert_eq(fast_import_parse_trim("hello"), "hello")
  assert_eq(fast_import_parse_trim("\n\thello\r\n"), "hello")
  assert_eq(fast_import_parse_trim(""), "")
}

///|
test "fast_import_parse_unquote_path: unquoted" {
  assert_eq(fast_import_parse_unquote_path("simple/path"), "simple/path")
}

///|
test "fast_import_parse_unquote_path: quoted" {
  assert_eq(
    fast_import_parse_unquote_path("\"path/with spaces\""),
    "path/with spaces",
  )
}

///|
test "fast_import_parse_unquote_path: escape sequences" {
  assert_eq(fast_import_parse_unquote_path("\"a\\nb\""), "a\nb")
  assert_eq(fast_import_parse_unquote_path("\"a\\tb\""), "a\tb")
  assert_eq(fast_import_parse_unquote_path("\"a\\\\b\""), "a\\b")
  assert_eq(fast_import_parse_unquote_path("\"a\\\"b\""), "a\"b")
}

///|
test "fast_import_parse_split_two_paths: unquoted" {
  let result = fast_import_parse_split_two_paths("old.txt new.txt")
  assert_eq(result, Some(("old.txt", "new.txt")))
}

///|
test "fast_import_parse_split_two_paths: first quoted" {
  let result = fast_import_parse_split_two_paths("\"old file.txt\" new.txt")
  assert_eq(result, Some(("old file.txt", "new.txt")))
}

///|
test "fast_import_parse_split_two_paths: no space" {
  let result = fast_import_parse_split_two_paths("single")
  assert_true(result is None)
}

///|
test "fast_import_parse_string_byte_count: ascii" {
  assert_eq(fast_import_parse_string_byte_count("hello"), 5)
  assert_eq(fast_import_parse_string_byte_count(""), 0)
  assert_eq(fast_import_parse_string_byte_count("ab cd"), 5)
}
