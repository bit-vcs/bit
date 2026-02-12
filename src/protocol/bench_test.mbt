///| Benchmarks for protocol operations

///|
/// Run with:
/// - moon bench -p mizchi/bit/protocol --target native -f bench_test.mbt

///|
let bench_pktline_str : String = "0039want ce013625030ba8dba906f756967f9e9ca394464a\n"

///|
fn make_1kb_bytes() -> Bytes {
  let arr : Array[Byte] = []
  for i in 0..<1024 {
    arr.push((i % 256).to_byte())
  }
  Bytes::from_array(arr)
}

///|
let bench_1kb_bytes : Bytes = make_1kb_bytes()

///|
fn make_encoded_packets(count : Int) -> Bytes {
  let parts : Array[Byte] = []
  for i in 0..<count {
    let line = "00000000000000000000000000000000000000\{i % 10} refs/heads/branch-\{i}\n"
    let encoded = @protocol.pktline_encode(line)
    for j in 0..<encoded.length() {
      parts.push(encoded[j])
    }
  }
  let flush = @protocol.pktline_flush()
  for j in 0..<flush.length() {
    parts.push(flush[j])
  }
  Bytes::from_array(parts)
}

///|
let bench_encoded_100 : Bytes = make_encoded_packets(100)

///|
fn make_refs_advertisement(count : Int) -> Bytes {
  let parts : Array[Byte] = []
  for i in 0..<count {
    let hex = "00000000000000000000000000000000000000" +
      (10 + i % 90).to_string()
    let line = if i == 0 {
      hex + " refs/heads/branch-\{i}\u0000 multi_ack thin-pack side-band\n"
    } else {
      hex + " refs/heads/branch-\{i}\n"
    }
    let encoded = @protocol.pktline_encode(line)
    for j in 0..<encoded.length() {
      parts.push(encoded[j])
    }
  }
  let flush = @protocol.pktline_flush()
  for j in 0..<flush.length() {
    parts.push(flush[j])
  }
  Bytes::from_array(parts)
}

///|
let bench_refs_50 : Bytes = make_refs_advertisement(50)

///|
fn make_want_ids() -> Array[@git.ObjectId] {
  let ids : Array[@git.ObjectId] = []
  for i in 0..<5 {
    let hex = "00000000000000000000000000000000000000" + (10 + i).to_string()
    ids.push(try! @git.ObjectId::from_hex(hex))
  }
  ids
}

///|
let bench_want_ids : Array[@git.ObjectId] = make_want_ids()

///|
let bench_caps : Array[String] = [
  "multi_ack", "thin-pack", "side-band", "side-band-64k", "ofs-delta", "shallow",
  "no-progress",
]

///|
fn make_push_request() -> @protocol.PushRequest {
  let old_id = @git.ObjectId::zero()
  let new_id = try! @git.ObjectId::from_hex(
    "ce013625030ba8dba906f756967f9e9ca394464a",
  )
  let packfile = Bytes::from_array([
    b'P', b'A', b'C', b'K', 0, 0, 0, 2, 0, 0, 0, 0,
  ])
  @protocol.PushRequest::new(old_id, new_id, "refs/heads/main", packfile)
}

///|
let bench_push_req : @protocol.PushRequest = make_push_request()

///|
test "bench pktline_encode" (b : @bench.T) {
  b.bench(fn() {
    let encoded = @protocol.pktline_encode(bench_pktline_str)
    b.keep(encoded.length())
  })
}

///|
test "bench pktline_encode_bytes 1KB" (b : @bench.T) {
  b.bench(fn() {
    let encoded = @protocol.pktline_encode_bytes(bench_1kb_bytes)
    b.keep(encoded.length())
  })
}

///|
test "bench pktline_decode 100 packets" (b : @bench.T) {
  b.bench(fn() {
    let packets = try! @protocol.pktline_decode(bench_encoded_100)
    b.keep(packets.length())
  })
}

///|
test "bench parse_refs 50 refs" (b : @bench.T) {
  b.bench(fn() {
    let refs = try! @protocol.parse_refs(bench_refs_50)
    b.keep(refs.length())
  })
}

///|
test "bench build_fetch_request_v2" (b : @bench.T) {
  b.bench(fn() {
    let req = @protocol.build_fetch_request_v2("git/moonbit", bench_want_ids, 0)
    b.keep(req.length())
  })
}

///|
test "bench build_fetch_request_v0" (b : @bench.T) {
  b.bench(fn() {
    let req = @protocol.build_fetch_request_v0(
      "git/moonbit", bench_want_ids, bench_caps,
    )
    b.keep(req.length())
  })
}

///|
test "bench parse_remote http" (b : @bench.T) {
  b.bench(fn() {
    let spec = @protocol.parse_remote("https://github.com/user/repo.git")
    b.keep(spec.path.length())
  })
}

///|
test "bench parse_remote ssh" (b : @bench.T) {
  b.bench(fn() {
    let spec = @protocol.parse_remote("git@github.com:user/repo.git")
    b.keep(spec.path.length())
  })
}

///|
test "bench build_receive_pack_body" (b : @bench.T) {
  b.bench(fn() {
    let body = @protocol.build_receive_pack_body(bench_push_req)
    b.keep(body.length())
  })
}
