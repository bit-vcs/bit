///|
fn Sha1State::process_block(self : Sha1State) -> Unit {
  let h = self.h
  let w : FixedArray[Int] = self.w
  let block = self.block
  for i = 0; i < 16; i = i + 1 {
    w[i] = (block[i * 4].to_int() << 24) |
      (block[i * 4 + 1].to_int() << 16) |
      (block[i * 4 + 2].to_int() << 8) |
      block[i * 4 + 3].to_int()
  }
  for i in 16..<80 {
    w[i] = sha1_rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
  }
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  for i = 0; i < 20; i = i + 1 {
    let f = (b & c) | (b.lnot() & d)
    let temp = (sha1_rotl32(a, 5) + f + e + 0x5a827999 + w[i]) & 0xffffffff
    e = d; d = c; c = sha1_rotl32(b, 30); b = a; a = temp
  }
  for i = 20; i < 40; i = i + 1 {
    let f = b ^ c ^ d
    let temp = (sha1_rotl32(a, 5) + f + e + 0x6ed9eba1 + w[i]) & 0xffffffff
    e = d; d = c; c = sha1_rotl32(b, 30); b = a; a = temp
  }
  for i = 40; i < 60; i = i + 1 {
    let f = (b & c) | (b & d) | (c & d)
    let temp = (sha1_rotl32(a, 5) + f + e + 0x8f1bbcdc + w[i]) & 0xffffffff
    e = d; d = c; c = sha1_rotl32(b, 30); b = a; a = temp
  }
  for i = 60; i < 80; i = i + 1 {
    let f = b ^ c ^ d
    let temp = (sha1_rotl32(a, 5) + f + e + 0xca62c1d6 + w[i]) & 0xffffffff
    e = d; d = c; c = sha1_rotl32(b, 30); b = a; a = temp
  }
  h[0] = (h[0] + a) & 0xffffffff
  h[1] = (h[1] + b) & 0xffffffff
  h[2] = (h[2] + c) & 0xffffffff
  h[3] = (h[3] + d) & 0xffffffff
  h[4] = (h[4] + e) & 0xffffffff
}

///|
fn sha1_rotl32(x : Int, n : Int) -> Int {
  ((x << n) | (x.reinterpret_as_uint() >> (32 - n)).reinterpret_as_int()) &
  0xffffffff
}

///|
pub fn sha1_raw(data : Bytes) -> FixedArray[Byte] {
  let b = @simdhash.sha1(data)
  let result : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  for i in 0..<20 {
    result[i] = b[i]
  }
  result
}
