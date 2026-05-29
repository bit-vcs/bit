///| Relay signing tests for pure WASM-compatible helpers.

///|
test "relay sign wasm: unix timestamp is populated" {
  assert_true(relay_unix_timestamp_sec() > 0L)
}

///|
test "relay sign wasm: signing key auto-load is disabled" {
  assert_eq(relay_load_signing_key(), None)
}

///|
async test "relay sign wasm: sha256 matches known digest" {
  assert_eq(
    relay_sha256_hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}
