///|
test "view-relative byte and sequence search" {
  let backing = b"!!abcab!"
  let view = backing[2:7]
  @debug.debug_inspect(@bytes_view.find_byte(view, b'a'), content="Some(0)")
  @debug.debug_inspect(@bytes_view.rev_find_byte(view, b'a'), content="Some(3)")
  @debug.debug_inspect(@bytes_view.find(view, b"bc"[:]), content="Some(1)")
  @debug.debug_inspect(@bytes_view.find(view, b""[:]), content="Some(0)")
}

///|
test "view bounds exclude surrounding bytes" {
  let backing = b"ZaaaaZ"
  let view = backing[1:5]
  @debug.debug_inspect(@bytes_view.find_byte(view, b'Z'), content="None")
  @debug.debug_inspect(@bytes_view.rev_find_byte(view, b'Z'), content="None")
}

///|
test "view equality, shortlex comparison, and non-ASCII scan" {
  let source = b"_abc_"
  @debug.debug_inspect(
    @bytes_view.equal(source[1:4], b"abc"[:]),
    content="true",
  )
  @debug.debug_inspect(
    @bytes_view.equal(source[1:4], b"abd"[:]),
    content="false",
  )
  @debug.debug_inspect(@bytes_view.compare(b"z"[:], b"aa"[:]), content="-1")
  @debug.debug_inspect(
    @bytes_view.compare(source[1:4], b"abd"[:]),
    content="-1",
  )
  @debug.debug_inspect(
    @bytes_view.find_non_ascii(b"_abc\x80_"[1:5]),
    content="Some(3)",
  )
}
