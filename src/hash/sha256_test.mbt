///|
test "sha256_raw empty" {
  let got = sha256_raw(Bytes::from_array([])) |> raw_to_hex
  inspect(
    got,
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256_raw abc" {
  let got = sha256_raw(Bytes::from_array([b'a', b'b', b'c'])) |> raw_to_hex
  inspect(
    got,
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 incremental" {
  let state = Sha256State::new()
  state.update_string("abc")
  let got = state.finish_raw() |> raw_to_hex
  inspect(
    got,
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 64-byte block boundary" {
  // "abcd" * 16 = 64 bytes (exactly one block)
  let got = sha256_raw(
      Bytes::from_array([
        b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a',
        b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b',
        b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c',
        b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd',
        b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd', b'a', b'b', b'c', b'd',
      ]),
    )
    |> raw_to_hex
  inspect(
    got,
    content="625b41490b883891943c5fa54ad45d7c900b9b6e91e159334e320b1f5215a209",
  )
}
