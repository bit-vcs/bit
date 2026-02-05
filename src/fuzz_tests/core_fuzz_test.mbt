///|
fn build_bytes(rng : Lcg, len : Int) -> Bytes {
  Bytes::makei(len, fn(_i) { rng.next_byte() })
}

///|
test "fuzz: pktline decode" {
  let rng = Lcg::new(1234567)
  for _ in 0..<128 {
    let len = rng.next_int() % 512
    let data = build_bytes(rng, len)
    ignore(try? @protocol.pktline_decode(data))
  }
}

///|
test "fuzz: packfile parse stream" {
  let rng = Lcg::new(7654321)
  for _ in 0..<64 {
    let len = rng.next_int() % 2048
    let data = build_bytes(rng, len)
    ignore(try? @pack.parse_packfile_stream(data, fn(_obj) { () }))
  }
}

///|
test "fuzz: parse_tree" {
  let rng = Lcg::new(424242)
  for _ in 0..<128 {
    let len = rng.next_int() % 512
    let data = build_bytes(rng, len)
    ignore(try? @git.parse_tree(data))
  }
}
