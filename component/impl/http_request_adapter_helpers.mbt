///| WasmHttpClient request conversion helpers.

///|
fn wasmhttp_headers_to_pairs(
  headers : Map[String, String],
) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  for item in headers.to_array() {
    let (k, v) = item
    pairs.push((k, v))
  }
  pairs
}

///|
fn wasmhttp_bytes_to_array(content : Bytes) -> Array[Byte] {
  let body : Array[Byte] = Array::new(capacity=content.length())
  for i in 0..<content.length() {
    body.push(content[i])
  }
  body
}
