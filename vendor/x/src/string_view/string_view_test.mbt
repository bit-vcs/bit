///|
test "view-relative UTF-16 search" {
  let source = "xxab😀abyy"
  let view = source.exact_view(start=2, end=8)
  @debug.debug_inspect(@string_view.find(view, "ab"[:]), content="Some(0)")
  @debug.debug_inspect(@string_view.rev_find(view, "ab"[:]), content="Some(4)")
  @debug.debug_inspect(
    @string_view.find_code_unit(view, (0xD83D : UInt16)),
    content="Some(2)",
  )
  @debug.debug_inspect(
    @string_view.rev_find_code_unit(view, ('a' : UInt16)),
    content="Some(4)",
  )
  @debug.debug_inspect(@string_view.find(view, ""[:]), content="Some(0)")
  @debug.debug_inspect(@string_view.rev_find(view, ""[:]), content="Some(6)")
}

///|
test "view bounds exclude surrounding strings" {
  let source = "ZaaaaZ"
  let view = source.exact_view(start=1, end=5)
  @debug.debug_inspect(@string_view.find(view, "Z"[:]), content="None")
  @debug.debug_inspect(@string_view.rev_find(view, "Z"[:]), content="None")
}

///|
test "UTF-16 shortlex comparison" {
  let source = "_abc_"
  @debug.debug_inspect(@string_view.compare("z"[:], "aa"[:]), content="-1")
  @debug.debug_inspect(
    @string_view.compare(source[1:4], "abd"[:]),
    content="-1",
  )
}
