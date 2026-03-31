///| JS relay signing: Web Crypto API via extern "js".

///|
fn relay_sign_public_key() -> String? {
  match @sys.get_env_var("BIT_RELAY_SIGN_PUBLIC_KEY") {
    Some(value) => {
      let normalized = value.trim(chars=" \n\r\t").to_string()
      if normalized.length() > 0 {
        Some(normalized)
      } else {
        None
      }
    }
    None => None
  }
}

///|
pub fn relay_unix_timestamp_sec() -> Int64 {
  (@env.now() / 1000UL).reinterpret_as_int64()
}

///|
extern "js" fn js_load_signing_key() -> String =
  #| () => {
  #|   const filePath = process.env.BIT_RELAY_SIGN_PRIVATE_KEY_FILE;
  #|   if (filePath && filePath.trim().length > 0) {
  #|     try {
  #|       const fs = require('fs');
  #|       return fs.readFileSync(filePath.trim(), 'utf8');
  #|     } catch (e) {
  #|       return '';
  #|     }
  #|   }
  #|   const pemContent = process.env.BIT_RELAY_SIGN_PRIVATE_KEY;
  #|   if (pemContent && pemContent.trim().length > 0) {
  #|     return pemContent.trim();
  #|   }
  #|   return '';
  #| }

///|
pub fn relay_load_signing_key() -> String? {
  let pem = js_load_signing_key()
  if pem.length() > 0 {
    Some(pem)
  } else {
    None
  }
}

///|
pub async fn relay_sha256_hex(text : String) -> String raise @bit.GitError {
  relay_webcrypto_sha256_hex(text)
}

///|
pub async fn relay_sign_ed25519(
  key_source : String,
  message : String,
) -> String raise @bit.GitError {
  relay_webcrypto_sign_ed25519(key_source, message)
}

///|
pub async fn relay_resolve_public_key(
  key_source : String,
) -> String raise @bit.GitError {
  match relay_sign_public_key() {
    Some(explicit) => explicit
    None => relay_webcrypto_resolve_public_key(key_source)
  }
}
