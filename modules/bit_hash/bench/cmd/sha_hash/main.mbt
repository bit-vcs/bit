// SHA-1 / SHA-256 workload for moon-pprof profiling.

fn make_payload(len : Int) -> Bytes {
  Bytes::makei(len, fn(i) { ((i * 31 + 7) % 251).to_byte() })
}

fn main {
  let p64 = make_payload(64)
  let p1k = make_payload(1024)
  let p8k = make_payload(8192)
  let p64k = make_payload(65536)
  let payloads = [p64, p1k, p8k, p64k]
  let mut sink = 0
  for _ in 0..<500 {
    for p in payloads {
      let h1 = @simdhash.sha1(p)
      let h2 = @simdhash.sha256(p)
      sink = sink + h1[0].to_int() + h2[0].to_int()
    }
  }
  println(sink)
}
