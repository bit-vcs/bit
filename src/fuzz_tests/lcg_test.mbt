///|
/// Deterministic RNG for fuzz tests (LCG)
struct Lcg {
  mut state : Int
}

///|
fn Lcg::new(seed : Int) -> Lcg {
  let normalized = seed % 2147483647
  { state: if normalized > 0 { normalized } else { normalized + 2147483646 } }
}

///|
fn Lcg::next_int(self : Lcg) -> Int {
  self.state = (self.state * 1103515245 + 12345) % 2147483647
  self.state
}

///|
fn Lcg::next_byte(self : Lcg) -> Byte {
  let v = self.next_int() % 256
  v.to_byte()
}
