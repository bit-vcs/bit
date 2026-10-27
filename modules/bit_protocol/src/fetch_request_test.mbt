///|
fn fetch_request_lines(data : Bytes) -> Array[String] raise @bit.GitError {
  let lines : Array[String] = []
  for item in @bit_protocol.pktline_decode(data) {
    let (payload, is_flush) = item
    if is_flush {
      lines.push("<flush>")
    } else if payload.length() == 0 {
      lines.push("<delimiter>")
    } else {
      lines.push(@utf8.decode_lossy(payload[:]))
    }
  }
  lines
}

///|
fn fetch_response_concat(chunks : Array[Bytes]) -> Bytes {
  let bytes : Array[Byte] = []
  for chunk in chunks {
    for byte in chunk {
      bytes.push(byte)
    }
  }
  Bytes::from_array(FixedArray::makei(bytes.length(), i => bytes[i]))
}

///|
test "build protocol v2 fetch request with negotiation and shallow state" {
  let want = @bit.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let have = @bit.ObjectId::from_hex("88e38705fdbd3608cddbe904b67c731f3234c45b")
  let shallow = @bit.ObjectId::from_hex(
    "cc628ccd10742baea8241c5924df992b5c019f71",
  )
  let lines = fetch_request_lines(
    @bit_protocol.build_fetch_request_v2(
      "git/moonbit",
      [want],
      3,
      filter=@bit_protocol.FilterSpec::BlobNone,
      haves=[have],
      shallow=[shallow],
    ),
  )
  debug_inspect(
    lines,
    content=(
      #|[
      #|  "command=fetch\n",
      #|  "agent=git/moonbit\n",
      #|  "object-format=sha1\n",
      #|  "<delimiter>",
      #|  "no-progress\n",
      #|  "ofs-delta\n",
      #|  "shallow cc628ccd10742baea8241c5924df992b5c019f71\n",
      #|  "deepen 3\n",
      #|  "filter blob:none\n",
      #|  "want ce013625030ba8dba906f756967f9e9ca394464a\n",
      #|  "have 88e38705fdbd3608cddbe904b67c731f3234c45b\n",
      #|  "done\n",
      #|  "<flush>",
      #|]
    ),
  )
}

///|
test "build protocol v0 or v1 fetch request with negotiation and shallow state" {
  let want = @bit.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let have = @bit.ObjectId::from_hex("88e38705fdbd3608cddbe904b67c731f3234c45b")
  let shallow = @bit.ObjectId::from_hex(
    "cc628ccd10742baea8241c5924df992b5c019f71",
  )
  let lines = fetch_request_lines(
    @bit_protocol.build_fetch_request_v0(
      "git/moonbit",
      [want],
      [
        "agent=git/2.55.0", "filter", "ofs-delta", "shallow", "side-band-64k", "thin-pack",
      ],
      depth=3,
      filter=@bit_protocol.FilterSpec::BlobNone,
      haves=[have],
      shallow=[shallow],
    ),
  )
  debug_inspect(
    lines,
    content=(
      #|[
      #|  "want ce013625030ba8dba906f756967f9e9ca394464a side-band-64k ofs-delta shallow filter agent=git/moonbit\n",
      #|  "shallow cc628ccd10742baea8241c5924df992b5c019f71\n",
      #|  "deepen 3\n",
      #|  "filter blob:none\n",
      #|  "<flush>",
      #|  "have 88e38705fdbd3608cddbe904b67c731f3234c45b\n",
      #|  "done\n",
      #|  "<flush>",
      #|]
    ),
  )
}

///|
test "build protocol v0 or v1 fetch request falls back to small sideband" {
  let want = @bit.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let lines = fetch_request_lines(
    @bit_protocol.build_fetch_request_v0("git/moonbit", [want], ["side-band"]),
  )
  @test.assert_eq(
    lines[0],
    "want ce013625030ba8dba906f756967f9e9ca394464a side-band\n",
  )
}

///|
test "parse protocol v2 fetch response preserves shallow updates" {
  let shallow = "cc628ccd10742baea8241c5924df992b5c019f71"
  let unshallow = "88e38705fdbd3608cddbe904b67c731f3234c45b"
  let response = fetch_response_concat([
    @bit_protocol.pktline_encode("shallow-info\n"),
    @bit_protocol.pktline_encode("shallow \{shallow}\n"),
    @bit_protocol.pktline_encode("unshallow \{unshallow}\n"),
    @bit_protocol.pktline_delim(),
    @bit_protocol.pktline_encode("packfile\n"),
    @bit_protocol.pktline_encode_bytes(Bytes::from_array([b'\x01', b'P', b'A', b'C', b'K'])),
    @bit_protocol.pktline_flush(),
  ])
  let result = @bit_protocol.parse_fetch_response_v2(response)
  @test.assert_eq(result.pack, b"PACK")
  @test.assert_eq(result.shallow.length(), 1)
  @test.assert_eq(result.shallow[0].to_hex(), shallow)
  @test.assert_eq(result.unshallow.length(), 1)
  @test.assert_eq(result.unshallow[0].to_hex(), unshallow)
}

///|
test "parse protocol v0 or v1 fetch response preserves shallow updates" {
  let shallow = "cc628ccd10742baea8241c5924df992b5c019f71"
  let unshallow = "88e38705fdbd3608cddbe904b67c731f3234c45b"
  let response = fetch_response_concat([
    @bit_protocol.pktline_encode("shallow \{shallow}\n"),
    @bit_protocol.pktline_encode("unshallow \{unshallow}\n"),
    @bit_protocol.pktline_flush(),
    @bit_protocol.pktline_encode("NAK\n"),
    @bit_protocol.pktline_encode_bytes(Bytes::from_array([b'\x01', b'P', b'A', b'C', b'K'])),
    @bit_protocol.pktline_flush(),
  ])
  let result = @bit_protocol.parse_fetch_response_v0(response)
  @test.assert_eq(result.pack, b"PACK")
  @test.assert_eq(result.shallow.length(), 1)
  @test.assert_eq(result.shallow[0].to_hex(), shallow)
  @test.assert_eq(result.unshallow.length(), 1)
  @test.assert_eq(result.unshallow[0].to_hex(), unshallow)
}

///|
test "v2_fetch_supports_filter reads the fetch capability line" {
  assert_true(
    @bit_protocol.v2_fetch_supports_filter([
      "version 2", "ls-refs=unborn", "fetch=shallow wait-for-done filter",
    ]),
  )
  assert_false(
    @bit_protocol.v2_fetch_supports_filter([
      "version 2", "ls-refs=unborn", "fetch=shallow wait-for-done",
    ]),
  )
  assert_false(@bit_protocol.v2_fetch_supports_filter(["version 2"]))
}
