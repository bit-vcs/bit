// SHA-256 fallback for non-native targets (@simdhash).

///|
pub fn sha256_bytes(data : Bytes) -> Bytes {
  @simdhash.sha256(data)
}

///|
pub fn sha256_raw(data : Bytes) -> FixedArray[Byte] {
  let b = @simdhash.sha256(data)
  let result : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  for i in 0..<32 {
    result[i] = b[i]
  }
  result
}
