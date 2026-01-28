///| SHA-1 implementation for Git object hashing

///|
/// SHA-1 initial hash values
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
/// SHA-1 round constants
let sha1_k0 : Int = 0x5a827999

///|
let sha1_k1 : Int = 0x6ed9eba1

///|
let sha1_k2 : Int = 0x8f1bbcdc

///|
let sha1_k3 : Int = 0xca62c1d6

///|
/// Left rotate 32-bit integer
fn rotl32(x : Int, n : Int) -> Int {
  ((x << n) | (x.reinterpret_as_uint() >> (32 - n)).reinterpret_as_int()) &
  0xffffffff
}

///|
/// Process a single 512-bit (64-byte) block
fn sha1_process_block(block : FixedArray[Byte], h : FixedArray[Int]) -> Unit {
  // Prepare message schedule
  let w : FixedArray[Int] = FixedArray::make(80, 0)

  // Copy block into first 16 words (big-endian)
  for i = 0; i < 16; i = i + 1 {
    w[i] = (block[i * 4].to_int() << 24) |
      (block[i * 4 + 1].to_int() << 16) |
      (block[i * 4 + 2].to_int() << 8) |
      block[i * 4 + 3].to_int()
  }

  // Extend the sixteen 32-bit words into eighty 32-bit words
  for i = 16; i < 80; i = i + 1 {
    w[i] = rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
  }

  // Initialize working variables
  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]

  // Main loop
  for i = 0; i < 80; i = i + 1 {
    let (f, k) = if i < 20 {
      ((b & c) | (b.lnot() & d), sha1_k0)
    } else if i < 40 {
      (b ^ c ^ d, sha1_k1)
    } else if i < 60 {
      ((b & c) | (b & d) | (c & d), sha1_k2)
    } else {
      (b ^ c ^ d, sha1_k3)
    }
    let temp = (rotl32(a, 5) + f + e + k + w[i]) & 0xffffffff
    e = d
    d = c
    c = rotl32(b, 30)
    b = a
    a = temp
  }

  // Add to hash
  h[0] = (h[0] + a) & 0xffffffff
  h[1] = (h[1] + b) & 0xffffffff
  h[2] = (h[2] + c) & 0xffffffff
  h[3] = (h[3] + d) & 0xffffffff
  h[4] = (h[4] + e) & 0xffffffff
}

///|
/// Compute SHA-1 hash of data
pub fn sha1(data : Bytes) -> ObjectId {
  let h : FixedArray[Int] = [sha1_h0, sha1_h1, sha1_h2, sha1_h3, sha1_h4]
  let msg_len = data.length()
  let bit_len = msg_len * 8

  // Pad message: append 1 bit, then zeros, then 64-bit length
  // Padded length must be congruent to 56 (mod 64)
  let pad_len = if msg_len % 64 < 56 {
    56 - msg_len % 64
  } else {
    64 + 56 - msg_len % 64
  }
  let total_len = msg_len + pad_len + 8
  let padded : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')

  // Copy original data
  for i = 0; i < msg_len; i = i + 1 {
    padded[i] = data[i]
  }

  // Append 1 bit (0x80)
  padded[msg_len] = b'\x80'

  // Append length in bits (big-endian, 64-bit)
  // For messages < 2^32 bits, upper 32 bits are 0
  let len_offset = total_len - 8
  // Upper 32 bits (usually 0 for normal messages)
  padded[len_offset] = b'\x00'
  padded[len_offset + 1] = b'\x00'
  padded[len_offset + 2] = b'\x00'
  padded[len_offset + 3] = b'\x00'
  // Lower 32 bits
  padded[len_offset + 4] = ((bit_len >> 24) & 0xff).to_byte()
  padded[len_offset + 5] = ((bit_len >> 16) & 0xff).to_byte()
  padded[len_offset + 6] = ((bit_len >> 8) & 0xff).to_byte()
  padded[len_offset + 7] = (bit_len & 0xff).to_byte()

  // Process blocks
  let num_blocks = total_len / 64
  for i = 0; i < num_blocks; i = i + 1 {
    let block : FixedArray[Byte] = FixedArray::make(64, b'\x00')
    for j = 0; j < 64; j = j + 1 {
      block[j] = padded[i * 64 + j]
    }
    sha1_process_block(block, h)
  }

  // Convert hash to bytes
  let result : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  for i = 0; i < 5; i = i + 1 {
    result[i * 4] = ((h[i] >> 24) & 0xff).to_byte()
    result[i * 4 + 1] = ((h[i] >> 16) & 0xff).to_byte()
    result[i * 4 + 2] = ((h[i] >> 8) & 0xff).to_byte()
    result[i * 4 + 3] = (h[i] & 0xff).to_byte()
  }
  ObjectId::new(result)
}

///|
/// Compute SHA-1 hash of data from Array
pub fn sha1_array(data : Array[Byte]) -> ObjectId {
  sha1(Bytes::from_array(FixedArray::makei(data.length(), fn(i) { data[i] })))
}
