///|
/// SHA-256 pure-MoonBit implementation
let sha256_k : FixedArray[Int] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
let sha256_h0 : Int = 0x6a09e667

///|
let sha256_h1 : Int = 0xbb67ae85

///|
let sha256_h2 : Int = 0x3c6ef372

///|
let sha256_h3 : Int = 0xa54ff53a

///|
let sha256_h4 : Int = 0x510e527f

///|
let sha256_h5 : Int = 0x9b05688c

///|
let sha256_h6 : Int = 0x1f83d9ab

///|
let sha256_h7 : Int = 0x5be0cd19

///|
pub struct Sha256State {
  h : FixedArray[Int]
  block : FixedArray[Byte]
  w : FixedArray[Int]
  mut block_len : Int
  mut total_len : Int64
}

///|
pub fn Sha256State::new() -> Sha256State {
  {
    h: [
      sha256_h0, sha256_h1, sha256_h2, sha256_h3, sha256_h4, sha256_h5, sha256_h6,
      sha256_h7,
    ],
    block: FixedArray::make(64, b'\x00'),
    w: FixedArray::make(64, 0),
    block_len: 0,
    total_len: 0L,
  }
}

///|
pub fn Sha256State::reset(self : Sha256State) -> Unit {
  self.h[0] = sha256_h0
  self.h[1] = sha256_h1
  self.h[2] = sha256_h2
  self.h[3] = sha256_h3
  self.h[4] = sha256_h4
  self.h[5] = sha256_h5
  self.h[6] = sha256_h6
  self.h[7] = sha256_h7
  self.block_len = 0
  self.total_len = 0L
}

///|
fn sha256_rotr32(x : Int, n : Int) -> Int {
  (x.reinterpret_as_uint() >> n).reinterpret_as_int() | (x << (32 - n))
}

///|
fn Sha256State::process_block(self : Sha256State) -> Unit {
  let h = self.h
  let w = self.w
  let block = self.block
  for i = 0; i < 16; i = i + 1 {
    w[i] = (block[i * 4].to_int() << 24) |
      (block[i * 4 + 1].to_int() << 16) |
      (block[i * 4 + 2].to_int() << 8) |
      block[i * 4 + 3].to_int()
  }
  for i = 16; i < 64; i = i + 1 {
    let s0 = sha256_rotr32(w[i - 15], 7) ^
      sha256_rotr32(w[i - 15], 18) ^
      (w[i - 15].reinterpret_as_uint() >> 3).reinterpret_as_int()
    let s1 = sha256_rotr32(w[i - 2], 17) ^
      sha256_rotr32(w[i - 2], 19) ^
      (w[i - 2].reinterpret_as_uint() >> 10).reinterpret_as_int()
    w[i] = w[i - 16] + s0 + w[i - 7] + s1
  }
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  let mut f = h[5]
  let mut g = h[6]
  let mut hh = h[7]
  for i = 0; i < 64; i = i + 1 {
    let s1 = sha256_rotr32(e, 6) ^ sha256_rotr32(e, 11) ^ sha256_rotr32(e, 25)
    let ch = (e & f) ^ (e.lnot() & g)
    let temp1 = hh + s1 + ch + sha256_k[i] + w[i]
    let s0 = sha256_rotr32(a, 2) ^ sha256_rotr32(a, 13) ^ sha256_rotr32(a, 22)
    let maj = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = s0 + maj
    hh = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }
  h[0] = h[0] + a
  h[1] = h[1] + b
  h[2] = h[2] + c
  h[3] = h[3] + d
  h[4] = h[4] + e
  h[5] = h[5] + f
  h[6] = h[6] + g
  h[7] = h[7] + hh
}

///|
pub fn Sha256State::update(self : Sha256State, data : Bytes) -> Unit {
  self.update_slice(data, 0, data.length())
}

///|
pub fn Sha256State::update_slice(
  self : Sha256State,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Unit {
  let mut pos = offset
  let end = offset + len
  self.total_len += len.to_int64()
  while pos < end {
    let space = 64 - self.block_len
    let to_copy = if end - pos < space { end - pos } else { space }
    for i in 0..<to_copy {
      self.block[self.block_len + i] = data[pos + i]
    }
    self.block_len += to_copy
    pos += to_copy
    if self.block_len == 64 {
      self.process_block()
      self.block_len = 0
    }
  }
}

///|
pub fn Sha256State::update_byte(self : Sha256State, b : Byte) -> Unit {
  self.block[self.block_len] = b
  self.block_len += 1
  self.total_len += 1L
  if self.block_len == 64 {
    self.process_block()
    self.block_len = 0
  }
}

///|
pub fn Sha256State::update_string(self : Sha256State, s : String) -> Unit {
  self.update(utf8_encode(s))
}

///|
pub fn Sha256State::finish_raw(self : Sha256State) -> FixedArray[Byte] {
  let bit_len = self.total_len * 8L
  self.block[self.block_len] = b'\x80'
  self.block_len += 1
  if self.block_len > 56 {
    while self.block_len < 64 {
      self.block[self.block_len] = b'\x00'
      self.block_len += 1
    }
    self.process_block()
    self.block_len = 0
  }
  while self.block_len < 56 {
    self.block[self.block_len] = b'\x00'
    self.block_len += 1
  }
  self.block[56] = ((bit_len >> 56) & 0xffL).to_byte()
  self.block[57] = ((bit_len >> 48) & 0xffL).to_byte()
  self.block[58] = ((bit_len >> 40) & 0xffL).to_byte()
  self.block[59] = ((bit_len >> 32) & 0xffL).to_byte()
  self.block[60] = ((bit_len >> 24) & 0xffL).to_byte()
  self.block[61] = ((bit_len >> 16) & 0xffL).to_byte()
  self.block[62] = ((bit_len >> 8) & 0xffL).to_byte()
  self.block[63] = (bit_len & 0xffL).to_byte()
  self.process_block()
  let result : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  for i = 0; i < 8; i = i + 1 {
    result[i * 4] = ((self.h[i] >> 24) & 0xff).to_byte()
    result[i * 4 + 1] = ((self.h[i] >> 16) & 0xff).to_byte()
    result[i * 4 + 2] = ((self.h[i] >> 8) & 0xff).to_byte()
    result[i * 4 + 3] = (self.h[i] & 0xff).to_byte()
  }
  result
}

///|
pub fn sha256_prefix_raw(data : Bytes, len : Int) -> FixedArray[Byte] {
  let msg_len = if len < 0 {
    0
  } else if len > data.length() {
    data.length()
  } else {
    len
  }
  let state = Sha256State::new()
  state.update_slice(data, 0, msg_len)
  state.finish_raw()
}

///|
pub fn sha256_array_prefix_raw(
  data : Array[Byte],
  len : Int,
) -> FixedArray[Byte] {
  let msg_len = if len < 0 {
    0
  } else if len > data.length() {
    data.length()
  } else {
    len
  }
  let state = Sha256State::new()
  for i in 0..<msg_len {
    state.update_byte(data[i])
  }
  state.finish_raw()
}

///|
pub fn sha256_array_raw(data : Array[Byte]) -> FixedArray[Byte] {
  sha256_array_prefix_raw(data, data.length())
}
