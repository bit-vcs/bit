///|
fn component_impl_fixture_receive_pack_advertisement() -> Bytes {
  let line = "0000000000000000000000000000000000000000 refs/heads/main\u0000report-status side-band-64k\n"
  let bytes : Array[Byte] = []
  for b in @protocol.pktline_encode(line) {
    bytes.push(b)
  }
  for b in @protocol.pktline_flush() {
    bytes.push(b)
  }
  Bytes::from_array(FixedArray::makei(bytes.length(), i => bytes[i]))
}

///|
fn component_impl_fixture_push_success_response() -> Bytes {
  let bytes : Array[Byte] = []
  for b in @protocol.pktline_encode("unpack ok\n") {
    bytes.push(b)
  }
  for b in @protocol.pktline_encode("ok refs/heads/main\n") {
    bytes.push(b)
  }
  for b in @protocol.pktline_flush() {
    bytes.push(b)
  }
  Bytes::from_array(FixedArray::makei(bytes.length(), i => bytes[i]))
}

///|
fn component_impl_fixture_upload_pack_v0_advertisement() -> Bytes {
  let bytes : Array[Byte] = []
  let head_line = component_impl_fixture_commit +
    " HEAD\u0000multi_ack symref=HEAD:refs/heads/main agent=git/moonbit\n"
  let main_line = component_impl_fixture_commit + " refs/heads/main\n"
  for b in @protocol.pktline_encode(head_line) {
    bytes.push(b)
  }
  for b in @protocol.pktline_encode(main_line) {
    bytes.push(b)
  }
  for b in @protocol.pktline_flush() {
    bytes.push(b)
  }
  Bytes::from_array(FixedArray::makei(bytes.length(), i => bytes[i]))
}
