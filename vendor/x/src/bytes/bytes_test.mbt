///|
test "find byte across SIMD boundaries" {
  for length in [0, 1, 15, 16, 17, 127, 128, 129, 4096] {
    for hit in [-1, 0, 1, 15, 16, length - 1] {
      if hit < length {
        let input = Bytes::makei(length, fn(i) {
          if i == hit {
            b'Z'
          } else {
            b'a'
          }
        })
        @debug.debug_inspect(
          @bytes.find_byte(input, b'Z'),
          content=if hit < 0 { "None" } else { "Some(\{hit})" },
        )
      }
    }
  }
}

///|
test "find byte returns the first occurrence" {
  @debug.debug_inspect(@bytes.find_byte(b"--Z--Z--", b'Z'), content="Some(2)")
  @debug.debug_inspect(@bytes.find_byte(b"abcdefgh", b'Z'), content="None")
}

///|
test "reverse find byte across SIMD boundaries" {
  for length in [0, 1, 15, 16, 17, 127, 128, 129, 4096] {
    let input = Bytes::makei(length, fn(i) {
      if i == 0 || i == length - 1 {
        b'Z'
      } else {
        b'a'
      }
    })
    @debug.debug_inspect(
      @bytes.rev_find_byte(input, b'Z'),
      content=if length == 0 { "None" } else { "Some(\{length - 1})" },
    )
  }
}

///|
test "find byte sequence" {
  @debug.debug_inspect(@bytes.find(b"abcabc", b"bca"[:]), content="Some(1)")
  @debug.debug_inspect(@bytes.find(b"abcabc", b"xyz"[:]), content="None")
  @debug.debug_inspect(@bytes.find(b"abc", b""[:]), content="Some(0)")
  @debug.debug_inspect(@bytes.find(b"ab", b"abc"[:]), content="None")
}

///|
test "find accepts an offset pattern view" {
  let pattern_source = b"--needle--"
  @debug.debug_inspect(
    @bytes.find(b"hay-needle-stack", pattern_source[2:8]),
    content="Some(4)",
  )
}

///|
test "find byte sequence across SIMD boundaries" {
  let input = Bytes::makei(4096, fn(i) {
    if i == 2047 {
      b'b'
    } else if i == 2048 {
      b'c'
    } else {
      b'a'
    }
  })
  @debug.debug_inspect(@bytes.find(input, b"bc"[:]), content="Some(2047)")
  @debug.debug_inspect(@bytes.find(input, b"bd"[:]), content="None")
}

///|
test "reverse find byte sequence" {
  @debug.debug_inspect(@bytes.rev_find(b"abcabc", b"abc"[:]), content="Some(3)")
  @debug.debug_inspect(@bytes.rev_find(b"abcabc", b"b"[:]), content="Some(4)")
  @debug.debug_inspect(@bytes.rev_find(b"abc", b""[:]), content="Some(3)")
  @debug.debug_inspect(@bytes.rev_find(b"abc", b"xyz"[:]), content="None")
}

///|
test "equal" {
  @debug.debug_inspect(@bytes.equal(b"", b""), content="true")
  @debug.debug_inspect(@bytes.equal(b"abc", b"abc"), content="true")
  @debug.debug_inspect(@bytes.equal(b"abc", b"abd"), content="false")
  @debug.debug_inspect(@bytes.equal(b"abc", b"abcd"), content="false")
  let left = Bytes::make(4096, b'a')
  let right = Bytes::make(4096, b'a')
  @debug.debug_inspect(@bytes.equal(left, right), content="true")
}

///|
test "compare preserves Bytes shortlex ordering" {
  @debug.debug_inspect(@bytes.compare(b"", b""), content="0")
  @debug.debug_inspect(@bytes.compare(b"z", b"aa"), content="-1")
  @debug.debug_inspect(@bytes.compare(b"aa", b"z"), content="1")
  @debug.debug_inspect(@bytes.compare(b"abc", b"abd"), content="-1")
  @debug.debug_inspect(@bytes.compare(b"abe", b"abd"), content="1")
  @debug.debug_inspect(@bytes.compare(b"abc", b"abc"), content="0")
  let long_left = Bytes::make(4096, b'a')
  let long_right = Bytes::makei(4096, fn(i) {
    if i == 4095 {
      b'b'
    } else {
      b'a'
    }
  })
  @debug.debug_inspect(@bytes.compare(long_left, long_right), content="-1")
}

///|
test "find non ASCII" {
  @debug.debug_inspect(@bytes.find_non_ascii(b""), content="None")
  @debug.debug_inspect(@bytes.find_non_ascii(b"plain ascii"), content="None")
  @debug.debug_inspect(@bytes.find_non_ascii(b"abc\x80def"), content="Some(3)")
  let long = Bytes::makei(4096, fn(i) { if i == 4095 { b'\xFF' } else { b'a' } })
  @debug.debug_inspect(@bytes.find_non_ascii(long), content="Some(4095)")
}
