// Cross-platform cryptographic hashes / HMAC, mirroring the
// `moonbitlang/x/crypto` API surface.
//
// `moonbitlang/x/crypto` is pure MoonBit and compiles to every target
// (native / wasm / wasm-gc / js — including browsers), so this package simply
// re-exposes its hash + HMAC + hex surface under the `mizchi/x` namespace by
// delegating to it. The synchronous signatures are preserved exactly; no FFI
// is involved (the Web Crypto `crypto.subtle` API is async-only and could not
// back this synchronous surface).

// Incremental hasher contexts, re-exported so `hmac` (which takes a
// `CryptoHasher`) and streaming hashing are usable from this package directly.

///|
pub using @upstream {type MD5}

///|
pub using @upstream {type SHA256}

///|
pub using @upstream {type SM3}

///|
/// Computes the MD5 digest of `data`.
pub fn[Data : @upstream.ByteSource] md5(data : Data) -> FixedArray[Byte] {
  @upstream.md5(data)
}

///|
/// Computes the SHA-1 digest of `data`.
pub fn[Data : @upstream.ByteSource] sha1(data : Data) -> FixedArray[Byte] {
  @upstream.sha1(data)
}

///|
/// Computes the SHA-224 digest of `data`.
pub fn[Data : @upstream.ByteSource] sha224(data : Data) -> FixedArray[Byte] {
  @upstream.sha224(data)
}

///|
/// Computes the SHA-224 digest of a byte iterator.
pub fn sha224_from_iter(iter : Iter[Byte]) -> FixedArray[Byte] {
  @upstream.sha224_from_iter(iter)
}

///|
/// Computes the SHA-256 digest of `data`.
pub fn[Data : @upstream.ByteSource] sha256(data : Data) -> FixedArray[Byte] {
  @upstream.sha256(data)
}

///|
/// Computes the SHA-256 digest of a byte iterator.
pub fn sha256_from_iter(iter : Iter[Byte]) -> FixedArray[Byte] {
  @upstream.sha256_from_iter(iter)
}

///|
/// Computes the SM3 digest of `data`.
pub fn[Data : @upstream.ByteSource] sm3(data : Data) -> FixedArray[Byte] {
  @upstream.sm3(data)
}

///|
/// Computes the SM3 digest of a byte iterator.
pub fn sm3_from_iter(iter : Iter[Byte]) -> FixedArray[Byte] {
  @upstream.sm3_from_iter(iter)
}

///|
/// Computes the HMAC of `message` under `key`, using `hasher` to choose the
/// digest (e.g. `SHA256::new()`).
pub fn[H : @upstream.CryptoHasher] hmac(
  hasher : H,
  key : BytesView,
  message : BytesView,
) -> FixedArray[Byte] {
  @upstream.hmac(hasher, key, message)
}

///|
/// Renders a byte source as a lowercase hex string.
pub fn[D : @upstream.ByteSource] bytes_to_hex_string(data : D) -> String {
  @upstream.bytes_to_hex_string(data)
}

///|
/// Renders a `UInt` iterator as a lowercase hex string.
pub fn uints_to_hex_string(iter : Iter[UInt32]) -> String {
  @upstream.uints_to_hex_string(iter)
}
