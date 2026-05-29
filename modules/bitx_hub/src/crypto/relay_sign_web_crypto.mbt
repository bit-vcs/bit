///|
/// Shared Web Crypto helpers for JS and WASM targets.
extern "js" fn relay_webcrypto_sha256_hex_impl(
  text : String,
) -> @js_async.Promise[String] =
  #| async (text) => {
  #|   const encoder = new TextEncoder();
  #|   const data = encoder.encode(text);
  #|   const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  #|   const hashArray = new Uint8Array(hashBuffer);
  #|   return Array.from(hashArray).map((b) => b.toString(16).padStart(2, '0')).join('');
  #| }

///|
extern "js" fn relay_webcrypto_sign_ed25519_impl(
  pem_key : String,
  message : String,
) -> @js_async.Promise[String] =
  #| async (pemKey, message) => {
  #|   const decodeBase64 = (value) => {
  #|     if (typeof atob === 'function') {
  #|       return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  #|     }
  #|     if (typeof Buffer !== 'undefined') {
  #|       return new Uint8Array(Buffer.from(value, 'base64'));
  #|     }
  #|     throw new Error('base64 decode is not available in this runtime');
  #|   };
  #|   const encodeBase64 = (bytes) => {
  #|     if (typeof btoa === 'function') {
  #|       let text = '';
  #|       for (let i = 0; i < bytes.length; i += 1) {
  #|         text += String.fromCharCode(bytes[i]);
  #|       }
  #|       return btoa(text);
  #|     }
  #|     if (typeof Buffer !== 'undefined') {
  #|       return Buffer.from(bytes).toString('base64');
  #|     }
  #|     throw new Error('base64 encode is not available in this runtime');
  #|   };
  #|   const pemBody = pemKey
  #|     .replace(/-----BEGIN[^-]*-----/, '')
  #|     .replace(/-----END[^-]*-----/, '')
  #|     .replace(/\s+/g, '');
  #|   const binaryDer = decodeBase64(pemBody);
  #|   const key = await crypto.subtle.importKey(
  #|     'pkcs8',
  #|     binaryDer,
  #|     { name: 'Ed25519' },
  #|     false,
  #|     ['sign'],
  #|   );
  #|   const encoder = new TextEncoder();
  #|   const data = encoder.encode(message);
  #|   const sigBuffer = await crypto.subtle.sign('Ed25519', key, data);
  #|   return encodeBase64(new Uint8Array(sigBuffer));
  #| }

///|
extern "js" fn relay_webcrypto_resolve_public_key_impl(
  pem_key : String,
) -> @js_async.Promise[String] =
  #| async (pemKey) => {
  #|   const decodeBase64 = (value) => {
  #|     if (typeof atob === 'function') {
  #|       return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  #|     }
  #|     if (typeof Buffer !== 'undefined') {
  #|       return new Uint8Array(Buffer.from(value, 'base64'));
  #|     }
  #|     throw new Error('base64 decode is not available in this runtime');
  #|   };
  #|   const pemBody = pemKey
  #|     .replace(/-----BEGIN[^-]*-----/, '')
  #|     .replace(/-----END[^-]*-----/, '')
  #|     .replace(/\s+/g, '');
  #|   const binaryDer = decodeBase64(pemBody);
  #|   const key = await crypto.subtle.importKey(
  #|     'pkcs8',
  #|     binaryDer,
  #|     { name: 'Ed25519' },
  #|     true,
  #|     ['sign'],
  #|   );
  #|   const jwk = await crypto.subtle.exportKey('jwk', key);
  #|   if (typeof jwk?.x !== 'string' || jwk.x.length === 0) {
  #|     throw new Error('missing Ed25519 public key component');
  #|   }
  #|   return jwk.x;
  #| }

///|
async fn relay_webcrypto_sha256_hex(
  text : String,
) -> String raise @bit.GitError {
  relay_webcrypto_sha256_hex_impl(text).wait() catch {
    err =>
      raise @bit.GitError::IoError(
        "relay sign: Web Crypto SHA-256 failed: \{err}",
      )
  }
}

///|
async fn relay_webcrypto_sign_ed25519(
  key_source : String,
  message : String,
) -> String raise @bit.GitError {
  let base64_sig = relay_webcrypto_sign_ed25519_impl(key_source, message).wait() catch {
    err =>
      raise @bit.GitError::IoError(
        "relay sign: Web Crypto Ed25519 sign failed: \{err}",
      )
  }
  relay_base64_to_base64url(base64_sig)
}

///|
async fn relay_webcrypto_resolve_public_key(
  key_source : String,
) -> String raise @bit.GitError {
  relay_webcrypto_resolve_public_key_impl(key_source).wait() catch {
    err =>
      raise @bit.GitError::IoError(
        "relay sign: Web Crypto public key export failed: \{err}",
      )
  }
}
