///|
fn remote_refname_test_pkts(lines : Array[String]) -> Bytes {
  let out : Array[Byte] = []
  for line in lines {
    for b in @bit_protocol.pktline_encode(line) {
      out.push(b)
    }
  }
  for b in @bit_protocol.pktline_flush() {
    out.push(b)
  }
  Bytes::from_array(out)
}

///|
let remote_refname_test_oid = "1111111111111111111111111111111111111111"

///|
test "ls-refs: server ref names that escape refs/ are dropped (CVE-2026-113408)" {
  let oid = remote_refname_test_oid
  let result = @bit_protocol.parse_ls_refs_response(
    remote_refname_test_pkts([
      "\{oid} HEAD symref-target:refs/heads/../../../../x\n",
      "\{oid} refs/heads/main\n",
      "\{oid} ../../../../tmp/x\n",
      "\{oid} refs/heads/../../heads/victim\n",
      "\{oid} hooks/pre-commit\n",
    ]),
  )
  let names = result.refs.map(r => r.1)
  assert_eq(names, ["HEAD", "refs/heads/main"])
  assert_eq(result.symrefs.get("HEAD"), None)
}

///|
test "ls-refs: unborn HEAD keeps a valid symref and records no ref" {
  let oid = remote_refname_test_oid
  let ok = @bit_protocol.parse_ls_refs_response(
    remote_refname_test_pkts(["unborn HEAD symref-target:refs/heads/main\n"]),
  )
  assert_eq(ok.refs.length(), 0)
  assert_eq(ok.symrefs.get("HEAD"), Some("refs/heads/main"))
  let evil = @bit_protocol.parse_ls_refs_response(
    remote_refname_test_pkts([
      "unborn HEAD symref-target:refs/heads/../../../../x\n",
      "\{oid} refs/heads/main\n",
    ]),
  )
  assert_eq(evil.symrefs.get("HEAD"), None)
  assert_eq(evil.refs.map(r => r.1), ["refs/heads/main"])
}

///|
test "v0 advertisement and symref capabilities drop unsafe names" {
  let oid = remote_refname_test_oid
  let refs = @bit_protocol.parse_refs(
    remote_refname_test_pkts([
      "\{oid} HEAD\u0000multi_ack symref=HEAD:refs/heads/main\n",
      "\{oid} refs/heads/main\n",
      "\{oid} refs/tags/v1^{}\n",
      "\{oid} refs/heads/../../../../x\n",
    ]),
  )
  assert_eq(refs.map(r => r.1), ["HEAD", "refs/heads/main", "refs/tags/v1^{}"])
  let caps = @bit_protocol.parse_symrefs_from_capabilities([
    "symref=HEAD:refs/heads/../../../../x", "symref=../x:refs/heads/main", "symref-target:refs/heads/../x",
  ])
  assert_eq(caps.length(), 0)
  let good = @bit_protocol.parse_symrefs_from_capabilities([
    "symref=HEAD:refs/heads/main",
  ])
  assert_eq(good.get("HEAD"), Some("refs/heads/main"))
}
