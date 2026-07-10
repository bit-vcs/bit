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
/// Always returns a non-negative Int. Callers can do `% N` without
/// worrying about negative remainders (and the `unsafe_to_char` /
/// out-of-bound array index footguns that follow).
fn Lcg::next_int(self : Lcg) -> Int {
  let next = (self.state * 1103515245 + 12345) % 2147483647
  // Overflow during the multiply (32-bit signed) can flip the sign.
  // Re-normalize to keep the public contract simple.
  self.state = if next < 0 { next + 2147483647 } else { next }
  self.state
}

///|
fn Lcg::next_byte(self : Lcg) -> Byte {
  (self.next_int() % 256).to_byte()
}
