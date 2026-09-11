///| Tests for the protocol v2 `ls-refs` command.

///|
fn ls_refs_repo() -> (@bit.TestFs, @bit.ObjectId) raise Error {
  let fs = @bit.TestFs::new()
  ignore(init_repo(fs, "/repo")) catch {
    _ => ()
  }
  fs.write_string("/repo/a.txt", "hello\n")
  add_paths(fs, fs, "/repo", ["a.txt"])
  let id = commit(
    fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
  )
  (fs, id)
}

///|
fn ls_refs_request(args : Array[String]) -> UploadPackRequestV2 raise Error {
  let chunks : Array[Bytes] = [@protocol.pktline_encode("command=ls-refs\n")]
  chunks.push(Bytes::from_array([b'0', b'0', b'0', b'1']))
  for arg in args {
    chunks.push(@protocol.pktline_encode(arg + "\n"))
  }
  chunks.push(@protocol.pktline_flush())
  parse_upload_pack_request_v2(test_concat_bytes(chunks))
}

///|
test "parse v2: ls-refs arguments are carried through" {
  let req = ls_refs_request([
    "peel", "symrefs", "unborn", "ref-prefix refs/heads/", "ref-prefix HEAD",
  ])
  assert_true(req.command == "ls-refs")
  assert_true(req.peel)
  assert_true(req.symrefs)
  assert_true(req.unborn)
  assert_true(req.ref_prefixes.length() == 2)
  assert_true(req.ref_prefixes[0] == "refs/heads/")
  assert_true(req.ref_prefixes[1] == "HEAD")
}

///|
test "ls-refs: lists HEAD and branches, flush-terminated" {
  let (fs, id) = ls_refs_repo()
  let out = ls_refs_v2(fs, "/repo", ls_refs_request([]))
  let text = @utf8.decode_lossy(out[:])
  assert_true(text.contains("\{id.to_hex()} HEAD"))
  assert_true(text.contains("\{id.to_hex()} refs/heads/main"))
  // A v2 command response ends with a flush packet.
  assert_true(text.has_suffix("0000"))
}

///|
test "ls-refs: a ref-prefix restricts the listing" {
  let (fs, id) = ls_refs_repo()
  let out = ls_refs_v2(fs, "/repo", ls_refs_request(["ref-prefix refs/heads/"]))
  let text = @utf8.decode_lossy(out[:])
  assert_true(text.contains("refs/heads/main"))
  // HEAD does not start with the prefix, so it must not be listed.
  assert_true(!text.contains("\{id.to_hex()} HEAD\n"))
}

///|
test "ls-refs: a prefix matching nothing yields only a flush" {
  let (fs, _) = ls_refs_repo()
  let out = ls_refs_v2(fs, "/repo", ls_refs_request(["ref-prefix refs/tags/"]))
  let text = @utf8.decode_lossy(out[:])
  assert_true(text == "0000")
}

///|
test "ls-refs: symrefs reports what HEAD points at" {
  let (fs, _) = ls_refs_repo()
  let out = ls_refs_v2(fs, "/repo", ls_refs_request(["symrefs"]))
  let text = @utf8.decode_lossy(out[:])
  assert_true(text.contains("HEAD symref-target:refs/heads/main"))
  // Only HEAD carries a symref target.
  assert_true(!text.contains("refs/heads/main symref-target:"))
}

///|
test "ls-refs: without symrefs no target is reported" {
  let (fs, _) = ls_refs_repo()
  let out = ls_refs_v2(fs, "/repo", ls_refs_request([]))
  assert_true(!@utf8.decode_lossy(out[:]).contains("symref-target:"))
}

///|
test "ls-refs: peel leaves a branch alone" {
  // A branch points straight at a commit, so there is nothing to peel and no
  // `peeled:` field should appear.
  let (fs, _) = ls_refs_repo()
  let out = ls_refs_v2(fs, "/repo", ls_refs_request(["peel"]))
  assert_true(!@utf8.decode_lossy(out[:]).contains("peeled:"))
}

///|
test "ls-refs: upload_pack_v2 dispatches the command" {
  // The bug this covers: v2 multiplexes commands over one endpoint, and a
  // server answering only `fetch` cannot complete a default `git clone`.
  let (fs, id) = ls_refs_repo()
  let config = build_upload_pack_config_with_overrides(fs, "/repo", Map([]))
  let out = upload_pack_v2(fs, "/repo", ls_refs_request([]), config)
  assert_true(@utf8.decode_lossy(out[:]).contains("\{id.to_hex()} HEAD"))
}

///|
test "ls-refs: an unknown command is still rejected" {
  let (fs, _) = ls_refs_repo()
  let chunks : Array[Bytes] = [
    @protocol.pktline_encode("command=bogus\n"),
    Bytes::from_array([b'0', b'0', b'0', b'1']),
    @protocol.pktline_flush(),
  ]
  let req = parse_upload_pack_request_v2(test_concat_bytes(chunks))
  let config = build_upload_pack_config_with_overrides(fs, "/repo", Map([]))
  let rejected = try {
    ignore(upload_pack_v2(fs, "/repo", req, config))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
/// A minimal report-status body, as `receive_build_status_response` emits.
fn ls_refs_status_bytes() -> Bytes {
  test_concat_bytes([
    @protocol.pktline_encode("unpack ok\n"),
    @protocol.pktline_encode("ok refs/heads/main\n"),
    @protocol.pktline_flush(),
  ])
}

///|
test "receive-pack: a client that did not ask for side-band gets the report raw" {
  let status = ls_refs_status_bytes()
  let out = receive_apply_side_band(status, ["report-status"])
  assert_true(out == status)
}

///|
test "receive-pack: side-band-64k wraps the report in band 1" {
  // The bug this covers: the advertisement offers side-band-64k, so git
  // selects it and then fails with "protocol error: bad band" if the report
  // arrives unframed.
  let status = ls_refs_status_bytes()
  let out = receive_apply_side_band(status, ["report-status", "side-band-64k"])
  assert_true(out != status)
  // pkt-line length covers the payload plus its 4-byte header and band byte.
  let expected_len = status.length() + 5
  let header = @utf8.decode_lossy(out[0:4])
  assert_true(header == @bithash.int_to_hex4(expected_len))
  // Band 1 marks payload.
  assert_true(out[4] == b'\x01')
  // The original bytes follow, and the stream ends with a flush.
  for i in 0..<status.length() {
    assert_true(out[5 + i] == status[i])
  }
  let tail = @utf8.decode_lossy(out[out.length() - 4:out.length()])
  assert_true(tail == "0000")
}

///|
test "receive-pack: a report larger than one packet is split across bands" {
  // 65515 is the most payload one pkt-line can carry alongside the band byte.
  let big = Bytes::makei(70000, _ => b'x')
  let out = receive_apply_side_band(big, ["side-band-64k"])
  let first_len = @utf8.decode_lossy(out[0:4])
  assert_true(first_len == @bithash.int_to_hex4(65520))
  assert_true(out[4] == b'\x01')
  // Second packet starts right after the first and carries the remainder.
  let second_start = 65520
  let second_len = @utf8.decode_lossy(out[second_start:second_start + 4])
  assert_true(second_len == @bithash.int_to_hex4(70000 - 65515 + 5))
  assert_true(out[second_start + 4] == b'\x01')
}

///|
fn v2_fetch_request(args : Array[String]) -> UploadPackRequestV2 raise Error {
  let chunks : Array[Bytes] = [@protocol.pktline_encode("command=fetch\n")]
  chunks.push(Bytes::from_array([b'0', b'0', b'0', b'1']))
  for arg in args {
    chunks.push(@protocol.pktline_encode(arg + "\n"))
  }
  chunks.push(@protocol.pktline_flush())
  parse_upload_pack_request_v2(test_concat_bytes(chunks))
}

///|
test "v2 fetch: a negotiation round always names the acknowledgments section" {
  let (fs, id) = ls_refs_repo()
  let config = build_upload_pack_config_with_overrides(fs, "/repo", Map([]))
  // `have` for an object the server knows, and no `done`.
  let req = v2_fetch_request(["want \{id.to_hex()}", "have \{id.to_hex()}"])
  let text = @utf8.decode_lossy(upload_pack_v2(fs, "/repo", req, config)[:])
  assert_true(text.contains("acknowledgments"))
  assert_true(text.contains("ACK \{id.to_hex()}"))
  // Without `ready`, nothing else may follow.
  assert_true(!text.contains("packfile"))
  assert_true(!text.contains("ready"))
  assert_true(text.has_suffix("0000"))
}

///|
test "v2 fetch: an unrecognised have still gets a NAK, not an empty response" {
  let (fs, id) = ls_refs_repo()
  let config = build_upload_pack_config_with_overrides(fs, "/repo", Map([]))
  // Not ce013625... — that is the SHA-1 of "hello\n", which this fixture
  // repository actually contains, so the server would rightly ACK it.
  let unknown = "0123456789abcdef0123456789abcdef01234567"
  let req = v2_fetch_request(["want \{id.to_hex()}", "have \{unknown}"])
  let text = @utf8.decode_lossy(upload_pack_v2(fs, "/repo", req, config)[:])
  assert_true(text.contains("acknowledgments"))
  assert_true(text.contains("NAK"))
  assert_true(!text.contains("packfile"))
}

///|
test "v2 fetch: done sends the pack with no acknowledgments section" {
  // The bug this covers: git rejects a response whose acknowledgments
  // section is followed by a packfile without an intervening `ready` —
  // "expected no other sections to be sent after no 'ready'".
  let (fs, id) = ls_refs_repo()
  let config = build_upload_pack_config_with_overrides(fs, "/repo", Map([]))
  let req = v2_fetch_request([
    "want \{id.to_hex()}", "have \{id.to_hex()}", "done",
  ])
  let text = @utf8.decode_lossy(upload_pack_v2(fs, "/repo", req, config)[:])
  assert_true(text.contains("packfile"))
  assert_true(!text.contains("acknowledgments"))
  assert_true(!text.contains("ACK "))
}

///|
test "v2 fetch: a clone with no haves sends the pack directly" {
  let (fs, id) = ls_refs_repo()
  let config = build_upload_pack_config_with_overrides(fs, "/repo", Map([]))
  let req = v2_fetch_request(["want \{id.to_hex()}", "done"])
  let text = @utf8.decode_lossy(upload_pack_v2(fs, "/repo", req, config)[:])
  assert_true(text.contains("packfile"))
  assert_true(!text.contains("acknowledgments"))
}
