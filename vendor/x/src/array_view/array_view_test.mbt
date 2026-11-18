///|
test "byte ArrayView search uses relative offsets" {
  let backing : FixedArray[Byte] = [
    b'!', b'!', b'a', b'b', b'c', b'a', b'b', b'!',
  ]
  let view = backing[2:7]
  let pattern : FixedArray[Byte] = [b'b', b'c']
  let reverse_pattern : FixedArray[Byte] = [b'a', b'b']
  @debug.debug_inspect(@array_view.find_byte(view, b'a'), content="Some(0)")
  @debug.debug_inspect(@array_view.rev_find_byte(view, b'a'), content="Some(3)")
  @debug.debug_inspect(@array_view.find(view, pattern[:]), content="Some(1)")
  @debug.debug_inspect(
    @array_view.rev_find(view, reverse_pattern[:]),
    content="Some(3)",
  )
}

///|
test "byte ArrayView bounds exclude surrounding bytes" {
  let backing : FixedArray[Byte] = [b'Z', b'a', b'b', b'c', b'Z']
  let view = backing[1:4]
  @debug.debug_inspect(@array_view.find_byte(view, b'Z'), content="None")
  @debug.debug_inspect(@array_view.rev_find_byte(view, b'Z'), content="None")
}
