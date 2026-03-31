///| Web Crypto relay signing tests for JS target.

///|
let relay_sign_test_private_key =
  #|-----BEGIN PRIVATE KEY-----
  #|MC4CAQAwBQYDK2VwBCIEIEYOzKBrnjy/eCL5x9n4fAniBKTxut5of1q69fXuIjc6
  #|-----END PRIVATE KEY-----

///|
let relay_sign_test_public_key = "5TGUn8TFuIFVAhxG23ehWzbZjqHra2fy_HmBihMT8f0"

///|
let relay_sign_test_message = "hello relay"

///|
fn relay_sign_test_restore_public_key_override(saved : String?) -> Unit {
  match saved {
    Some(value) => @sys.set_env_var("BIT_RELAY_SIGN_PUBLIC_KEY", value)
    None => @sys.unset_env_var("BIT_RELAY_SIGN_PUBLIC_KEY")
  }
}

///|
extern "js" fn relay_sign_test_verify_ed25519_impl(
  public_key : String,
  message : String,
  signature : String,
) -> @js_async.Promise[Bool] =
  #| async (publicKey, message, signature) => {
  #|   const decodeBase64 = (value) => {
  #|     const normalized = String(value).replace(/-/g, '+').replace(/_/g, '/');
  #|     const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  #|     if (typeof atob === 'function') {
  #|       return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
  #|     }
  #|     if (typeof Buffer !== 'undefined') {
  #|       return new Uint8Array(Buffer.from(padded, 'base64'));
  #|     }
  #|     throw new Error('base64 decode is not available in this runtime');
  #|   };
  #|   const key = await crypto.subtle.importKey(
  #|     'raw',
  #|     decodeBase64(publicKey),
  #|     { name: 'Ed25519' },
  #|     false,
  #|     ['verify'],
  #|   );
  #|   const data = new TextEncoder().encode(message);
  #|   return crypto.subtle.verify('Ed25519', key, decodeBase64(signature), data);
  #| }

///|
async fn relay_sign_test_verify_ed25519(
  public_key : String,
  message : String,
  signature : String,
) -> Bool raise @bit.GitError {
  relay_sign_test_verify_ed25519_impl(public_key, message, signature).wait() catch {
    err =>
      raise @bit.GitError::IoError(
        "relay sign test: Web Crypto Ed25519 verify failed: \{err}",
      )
  }
}

///|
test "relay sign web: unix timestamp is populated" {
  assert_true(relay_unix_timestamp_sec() > 0L)
}

///|
async test "relay sign web: sha256 matches known digest" {
  assert_eq(
    relay_sha256_hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
async test "relay sign web: resolves public key and signs with Ed25519" {
  let saved_public_key = @sys.get_env_var("BIT_RELAY_SIGN_PUBLIC_KEY")
  @sys.unset_env_var("BIT_RELAY_SIGN_PUBLIC_KEY")
  let public_key = relay_resolve_public_key(relay_sign_test_private_key)
  assert_eq(public_key, relay_sign_test_public_key)
  let signature = relay_sign_ed25519(
    relay_sign_test_private_key, relay_sign_test_message,
  )
  assert_true(signature.length() > 0)
  assert_true(
    relay_sign_test_verify_ed25519(
      relay_sign_test_public_key, relay_sign_test_message, signature,
    ),
  )
  relay_sign_test_restore_public_key_override(saved_public_key)
}
