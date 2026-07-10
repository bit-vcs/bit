///|
test "parse refs from pkt-line format" {
  let line1 = "ce013625030ba8dba906f756967f9e9ca394464a refs/heads/main\n"
  let line2 = "cc628ccd10742baea8241c5924df992b5c019f71 refs/heads/feature\n"
  let out : Array[Byte] = []
  for b in pktline_encode(line1) {
    out.push(b)
  }
  for b in pktline_encode(line2) {
    out.push(b)
  }
  for b in pktline_flush() {
    out.push(b)
  }
  let refs_bytes = Bytes::from_array(
    FixedArray::makei(out.length(), fn(i) { out[i] }),
  )
  let refs = parse_refs(refs_bytes)
  assert_true(refs.length() == 2)
  let (id1, name1) = refs[0]
  let (id2, name2) = refs[1]
  assert_true(name1 == "refs/heads/main")
  assert_true(id1.to_hex() == "ce013625030ba8dba906f756967f9e9ca394464a")
  assert_true(name2 == "refs/heads/feature")
  assert_true(id2.to_hex() == "cc628ccd10742baea8241c5924df992b5c019f71")
}
