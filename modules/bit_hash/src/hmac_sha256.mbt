///|
/// HMAC-SHA256 (RFC 2104), built on this package's SHA-256 primitive.
///
/// Needed by AWS SigV4 request signing, which derives its signing key through
/// a chain of four HMACs.
const HMAC_SHA256_BLOCK : Int = 64

///|
/// Normalize a key to exactly one SHA-256 block: hash it when it is longer
/// than the block, then zero-pad to the block size.
fn hmac_sha256_block_key(key : Bytes) -> FixedArray[Byte] {
  let block : FixedArray[Byte] = FixedArray::make(HMAC_SHA256_BLOCK, b'\x00')
  let normalized = if key.length() > HMAC_SHA256_BLOCK {
    let digest = sha256_raw(key)
    Bytes::makei(digest.length(), i => digest[i])
  } else {
    key
  }
  for i in 0..<normalized.length() {
    block[i] = normalized[i]
  }
  block
}

///|
/// HMAC-SHA256 as a raw 32-byte digest.
pub fn hmac_sha256_raw(key : Bytes, msg : Bytes) -> FixedArray[Byte] {
  let block = hmac_sha256_block_key(key)
  let inner = Sha256State::new()
  for i in 0..<HMAC_SHA256_BLOCK {
    inner.update_byte(block[i].lxor(b'\x36'))
  }
  inner.update(msg)
  let inner_digest = inner.finish_raw()
  let outer = Sha256State::new()
  for i in 0..<HMAC_SHA256_BLOCK {
    outer.update_byte(block[i].lxor(b'\x5c'))
  }
  for i in 0..<inner_digest.length() {
    outer.update_byte(inner_digest[i])
  }
  outer.finish_raw()
}

///|
/// HMAC-SHA256 as a 32-byte `Bytes`.
pub fn hmac_sha256_bytes(key : Bytes, msg : Bytes) -> Bytes {
  let digest = hmac_sha256_raw(key, msg)
  Bytes::makei(digest.length(), i => digest[i])
}
