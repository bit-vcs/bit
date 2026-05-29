// SHA-256 fallback for non-native targets (uses @crypto).

///|
pub fn sha256_raw(data : Bytes) -> FixedArray[Byte] {
  sha256_prefix_raw(data, data.length())
}
