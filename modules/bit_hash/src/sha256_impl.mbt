///|
pub fn sha256_raw(data : Bytes) -> FixedArray[Byte] {
  let b = @simdhash.sha256(data)
  let result : FixedArray[Byte] = FixedArray::make(32, b'\x00')
  for i in 0..<32 {
    result[i] = b[i]
  }
  result
}
