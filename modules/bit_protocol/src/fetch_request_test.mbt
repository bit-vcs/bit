///|
fn fetch_request_lines(data : Bytes) -> Array[String] raise @bit.GitError {
  let lines : Array[String] = []
  for item in pktline_decode(data) {
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
test "build protocol v2 fetch request with negotiation and shallow state" {
  let want = @bit.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let have = @bit.ObjectId::from_hex("88e38705fdbd3608cddbe904b67c731f3234c45b")
  let shallow = @bit.ObjectId::from_hex(
    "cc628ccd10742baea8241c5924df992b5c019f71",
  )
  let lines = fetch_request_lines(
    build_fetch_request_v2(
      "git/moonbit",
      [want],
      depth=3,
      filter=FilterSpec::BlobNone,
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
    build_fetch_request_v0(
      "git/moonbit",
      [want],
      [
        "agent=git/2.55.0", "filter", "ofs-delta", "shallow", "side-band-64k", "thin-pack",
      ],
      depth=3,
      filter=FilterSpec::BlobNone,
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
    build_fetch_request_v0("git/moonbit", [want], ["side-band"]),
  )
  @test.assert_eq(
    lines[0],
    "want ce013625030ba8dba906f756967f9e9ca394464a side-band\n",
  )
}

///|
test "fetch request depth is optional and unshallow is explicit" {
  let want = @bit.ObjectId::from_hex("ce013625030ba8dba906f756967f9e9ca394464a")
  let shallow = @bit.ObjectId::from_hex(
    "cc628ccd10742baea8241c5924df992b5c019f71",
  )
  let regular = fetch_request_lines(
    build_fetch_request_v2("git/moonbit", [want], shallow=[shallow]),
  )
  assert_false(regular.any(line => line.has_prefix("deepen ")))
  let unshallow = fetch_request_lines(
    build_fetch_request_v0(
      "git/moonbit",
      [want],
      ["shallow"],
      shallow=[shallow],
      unshallow=true,
    ),
  )
  assert_true(unshallow.contains("deepen 2147483647\n"))
}
