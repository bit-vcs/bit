///| SHA-1 core implementation (hash package)

///|
let sha1_h0 : Int = 0x67452301

///|
let sha1_h1 : Int = 0xefcdab89

///|
let sha1_h2 : Int = 0x98badcfe

///|
let sha1_h3 : Int = 0x10325476

///|
let sha1_h4 : Int = 0xc3d2e1f0

///|
pub struct Sha1State {
  h : FixedArray[Int]
  block : FixedArray[Byte]
  w : FixedArray[Int]
  mut block_len : Int
  mut total_len : Int64
}

///|
pub fn Sha1State::new() -> Sha1State {
  {
    h: [sha1_h0, sha1_h1, sha1_h2, sha1_h3, sha1_h4],
    block: FixedArray::make(64, b'\x00'),
    w: FixedArray::make(80, 0),
    block_len: 0,
    total_len: 0L,
  }
}

///|
pub fn Sha1State::reset(self : Sha1State) -> Unit {
  self.h[0] = sha1_h0
  self.h[1] = sha1_h1
  self.h[2] = sha1_h2
  self.h[3] = sha1_h3
  self.h[4] = sha1_h4
  self.block_len = 0
  self.total_len = 0L
}


///|
pub fn Sha1State::update(self : Sha1State, data : Bytes) -> Unit {
  self.update_slice(data, 0, data.length())
}

///|
pub fn Sha1State::update_slice(
  self : Sha1State,
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
pub fn Sha1State::update_byte(self : Sha1State, b : Byte) -> Unit {
  self.block[self.block_len] = b
  self.block_len += 1
  self.total_len += 1L
  if self.block_len == 64 {
    self.process_block()
    self.block_len = 0
  }
}

///|
pub fn Sha1State::update_string(self : Sha1State, s : String) -> Unit {
  self.update(utf8_encode(s))
}

///|
pub fn Sha1State::finish_raw(self : Sha1State) -> FixedArray[Byte] {
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
  let result : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  for i = 0; i < 5; i = i + 1 {
    result[i * 4] = ((self.h[i] >> 24) & 0xff).to_byte()
    result[i * 4 + 1] = ((self.h[i] >> 16) & 0xff).to_byte()
    result[i * 4 + 2] = ((self.h[i] >> 8) & 0xff).to_byte()
    result[i * 4 + 3] = (self.h[i] & 0xff).to_byte()
  }
  result
}

///|
pub fn sha1_prefix_raw(data : Bytes, len : Int) -> FixedArray[Byte] {
  let msg_len = if len < 0 {
    0
  } else if len > data.length() {
    data.length()
  } else {
    len
  }
  let state = Sha1State::new()
  state.update_slice(data, 0, msg_len)
  state.finish_raw()
}


///|
pub fn sha1_array_prefix_raw(data : Array[Byte], len : Int) -> FixedArray[Byte] {
  let msg_len = if len < 0 {
    0
  } else if len > data.length() {
    data.length()
  } else {
    len
  }
  let state = Sha1State::new()
  for i in 0..<msg_len {
    state.update_byte(data[i])
  }
  state.finish_raw()
}

///|
pub fn sha1_array_raw(data : Array[Byte]) -> FixedArray[Byte] {
  sha1_array_prefix_raw(data, data.length())
}
