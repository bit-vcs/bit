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
