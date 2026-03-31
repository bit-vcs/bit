///| WASM relay signing: pure MoonBit fallback where possible.

///|
pub fn relay_unix_timestamp_sec() -> Int64 {
  (@env.now() / 1000UL).reinterpret_as_int64()
}

///|
pub fn relay_load_signing_key() -> String? {
  None
}

///|
pub async fn relay_sha256_hex(text : String) -> String raise @bit.GitError {
  let digest = @mbcrypto.bytes_to_hex_string(
    @mbcrypto.sha256(@utf8.encode(text)),
  )
  if digest.length() == 0 {
    raise @bit.GitError::IoError(
      "relay sign: SHA-256 digest unexpectedly empty",
    )
  }
  digest
}

///|
pub async fn relay_sign_ed25519(
  key_source : String,
  message : String,
) -> String raise @bit.GitError {
  ignore(key_source)
  ignore(message)
  raise @bit.GitError::IoError(
    "relay sign: Ed25519 signing not supported on WASM target",
  )
}

///|
pub async fn relay_resolve_public_key(
  key_source : String,
) -> String raise @bit.GitError {
  ignore(key_source)
  raise @bit.GitError::IoError(
    "relay sign: public key export not supported on WASM target",
  )
}
