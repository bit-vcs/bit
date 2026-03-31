///|
test "component impl: http request adapter helpers convert headers and body bytes" {
  let header_pairs = wasmhttp_headers_to_pairs({
    "accept": "application/x-git-upload-pack-advertisement",
    "x-test": "1",
  })
  assert_eq(header_pairs.length(), 2)

  let body = wasmhttp_bytes_to_array(Bytes::from_array([1, 2, 3]))
  assert_eq(body, [1, 2, 3])
}
