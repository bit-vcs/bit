///| JS-exported local Git operations backed by `src/lib`.

///|
fn[T] js_wrap_error(f : () -> T raise @bit.GitError) -> Result[T, String] {
  Ok(f()) catch {
    @bit.GitError::IoError(error) => Err(error)
    @bit.GitError::InvalidObject(error) => Err(error)
    @bit.GitError::HashMismatch(expected, actual) =>
      Err("hash mismatch: \{expected} vs \{actual}")
    @bit.GitError::PackfileError(error) => Err("packfile error: \{error}")
    @bit.GitError::ProtocolError(error) => Err("protocol error: \{error}")
  }
}

///|
async fn[T] js_wrap_error_async(
  f : async () -> T raise @bit.GitError,
) -> Result[T, String] {
  Ok(f()) catch {
    @bit.GitError::IoError(error) => Err(error)
    @bit.GitError::InvalidObject(error) => Err(error)
    @bit.GitError::HashMismatch(expected, actual) =>
      Err("hash mismatch: \{expected} vs \{actual}")
    @bit.GitError::PackfileError(error) => Err("packfile error: \{error}")
    @bit.GitError::ProtocolError(error) => Err("protocol error: \{error}")
  }
}

///|
fn[T] js_export_promise(f : async () -> T) -> @js_async.Promise[T] {
  @js_async.Promise::from_async(f)
}

///|
extern "js" fn js_webcrypto_resolve_ssh_ed25519_public_key_impl(
  private_key_pem : String,
  comment : String,
) -> @js_async.Promise[String] =
  #| async (privateKeyPem, comment) => {
  #|   const helpers = globalThis.__bitGitJsSshSigHelpers ??= (() => {
  #|     const encoder = new TextEncoder();
  #|     const ensureSubtle = () => {
  #|       if (!globalThis.crypto?.subtle) {
  #|         throw new Error('Web Crypto SubtleCrypto is not available');
  #|       }
  #|       return globalThis.crypto.subtle;
  #|     };
  #|     const decodeBase64 = (value) => {
  #|       if (typeof atob === 'function') {
  #|         return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  #|       }
  #|       if (typeof Buffer !== 'undefined') {
  #|         return new Uint8Array(Buffer.from(value, 'base64'));
  #|       }
  #|       throw new Error('base64 decode is not available in this runtime');
  #|     };
  #|     const encodeBase64 = (bytes) => {
  #|       if (typeof btoa === 'function') {
  #|         let text = '';
  #|         for (let i = 0; i < bytes.length; i += 1) {
  #|           text += String.fromCharCode(bytes[i]);
  #|         }
  #|         return btoa(text);
  #|       }
  #|       if (typeof Buffer !== 'undefined') {
  #|         return Buffer.from(bytes).toString('base64');
  #|       }
  #|       throw new Error('base64 encode is not available in this runtime');
  #|     };
  #|     const base64UrlToBytes = (value) => {
  #|       const normalized = String(value ?? '').replace(/-/g, '+').replace(/_/g, '/');
  #|       const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  #|       return decodeBase64(padded);
  #|     };
  #|     const decodePem = (pem) => {
  #|       const body = String(pem ?? '')
  #|         .replace(/-----BEGIN[^-]*-----/, '')
  #|         .replace(/-----END[^-]*-----/, '')
  #|         .replace(/\s+/g, '');
  #|       if (!body) {
  #|         throw new Error('private key PEM is empty');
  #|       }
  #|       return decodeBase64(body);
  #|     };
  #|     const importPrivateKey = async (pem) => {
  #|       return ensureSubtle().importKey(
  #|         'pkcs8',
  #|         decodePem(pem),
  #|         { name: 'Ed25519' },
  #|         true,
  #|         ['sign'],
  #|       );
  #|     };
  #|     const exportPublicKeyRaw = async (pem) => {
  #|       const privateKey = await importPrivateKey(pem);
  #|       const jwk = await ensureSubtle().exportKey('jwk', privateKey);
  #|       if (typeof jwk?.x !== 'string' || jwk.x.length === 0) {
  #|         throw new Error('missing Ed25519 public key component');
  #|       }
  #|       return base64UrlToBytes(jwk.x);
  #|     };
  #|     const concatBytes = (...parts) => {
  #|       let total = 0;
  #|       for (const part of parts) total += part.length;
  #|       const out = new Uint8Array(total);
  #|       let offset = 0;
  #|       for (const part of parts) {
  #|         out.set(part, offset);
  #|         offset += part.length;
  #|       }
  #|       return out;
  #|     };
  #|     const uint32be = (value) => new Uint8Array([
  #|       (value >>> 24) & 0xff,
  #|       (value >>> 16) & 0xff,
  #|       (value >>> 8) & 0xff,
  #|       value & 0xff,
  #|     ]);
  #|     const sshString = (value) => {
  #|       const bytes = typeof value === 'string' ? encoder.encode(value) : value;
  #|       return concatBytes(uint32be(bytes.length), bytes);
  #|     };
  #|     const wrapBase64 = (value, width = 70) => {
  #|       const parts = [];
  #|       for (let i = 0; i < value.length; i += width) {
  #|         parts.push(value.slice(i, i + width));
  #|       }
  #|       return parts.join('\n');
  #|     };
  #|     const resolveSshEd25519PublicKey = async (pem, keyComment) => {
  #|       const publicKeyRaw = await exportPublicKeyRaw(pem);
  #|       const publicKeyWire = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(publicKeyRaw),
  #|       );
  #|       const suffix = String(keyComment ?? '').length > 0 ? ` ${String(keyComment)}` : '';
  #|       return `ssh-ed25519 ${encodeBase64(publicKeyWire)}${suffix}`;
  #|     };
  #|     const signGitPayloadSshEd25519 = async (pem, messageText) => {
  #|       const subtle = ensureSubtle();
  #|       const privateKey = await importPrivateKey(pem);
  #|       const publicKeyRaw = await exportPublicKeyRaw(pem);
  #|       const payloadBytes = encoder.encode(String(messageText ?? ''));
  #|       const payloadHash = new Uint8Array(
  #|         await subtle.digest('SHA-512', payloadBytes),
  #|       );
  #|       const signedData = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         sshString('git'),
  #|         sshString(new Uint8Array()),
  #|         sshString('sha512'),
  #|         sshString(payloadHash),
  #|       );
  #|       const rawSignature = new Uint8Array(
  #|         await subtle.sign('Ed25519', privateKey, signedData),
  #|       );
  #|       const publicKeyBlob = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(publicKeyRaw),
  #|       );
  #|       const signatureBlob = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(rawSignature),
  #|       );
  #|       const sshSigBlob = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         uint32be(1),
  #|         sshString(publicKeyBlob),
  #|         sshString('git'),
  #|         sshString(new Uint8Array()),
  #|         sshString('sha512'),
  #|         sshString(signatureBlob),
  #|       );
  #|       return (
  #|         '-----BEGIN SSH SIGNATURE-----\n' +
  #|         wrapBase64(encodeBase64(sshSigBlob)) +
  #|         '\n-----END SSH SIGNATURE-----\n'
  #|       );
  #|     };
  #|     return { resolveSshEd25519PublicKey, signGitPayloadSshEd25519 };
  #|   })();
  #|   return helpers.resolveSshEd25519PublicKey(privateKeyPem, comment);
  #| }

///|
extern "js" fn js_webcrypto_sign_git_payload_ssh_ed25519_impl(
  private_key_pem : String,
  payload : String,
) -> @js_async.Promise[String] =
  #| async (privateKeyPem, payload) => {
  #|   const helpers = globalThis.__bitGitJsSshSigHelpers ??= (() => {
  #|     const encoder = new TextEncoder();
  #|     const ensureSubtle = () => {
  #|       if (!globalThis.crypto?.subtle) {
  #|         throw new Error('Web Crypto SubtleCrypto is not available');
  #|       }
  #|       return globalThis.crypto.subtle;
  #|     };
  #|     const decodeBase64 = (value) => {
  #|       if (typeof atob === 'function') {
  #|         return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  #|       }
  #|       if (typeof Buffer !== 'undefined') {
  #|         return new Uint8Array(Buffer.from(value, 'base64'));
  #|       }
  #|       throw new Error('base64 decode is not available in this runtime');
  #|     };
  #|     const encodeBase64 = (bytes) => {
  #|       if (typeof btoa === 'function') {
  #|         let text = '';
  #|         for (let i = 0; i < bytes.length; i += 1) {
  #|           text += String.fromCharCode(bytes[i]);
  #|         }
  #|         return btoa(text);
  #|       }
  #|       if (typeof Buffer !== 'undefined') {
  #|         return Buffer.from(bytes).toString('base64');
  #|       }
  #|       throw new Error('base64 encode is not available in this runtime');
  #|     };
  #|     const base64UrlToBytes = (value) => {
  #|       const normalized = String(value ?? '').replace(/-/g, '+').replace(/_/g, '/');
  #|       const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  #|       return decodeBase64(padded);
  #|     };
  #|     const decodePem = (pem) => {
  #|       const body = String(pem ?? '')
  #|         .replace(/-----BEGIN[^-]*-----/, '')
  #|         .replace(/-----END[^-]*-----/, '')
  #|         .replace(/\s+/g, '');
  #|       if (!body) {
  #|         throw new Error('private key PEM is empty');
  #|       }
  #|       return decodeBase64(body);
  #|     };
  #|     const importPrivateKey = async (pem) => {
  #|       return ensureSubtle().importKey(
  #|         'pkcs8',
  #|         decodePem(pem),
  #|         { name: 'Ed25519' },
  #|         true,
  #|         ['sign'],
  #|       );
  #|     };
  #|     const exportPublicKeyRaw = async (pem) => {
  #|       const privateKey = await importPrivateKey(pem);
  #|       const jwk = await ensureSubtle().exportKey('jwk', privateKey);
  #|       if (typeof jwk?.x !== 'string' || jwk.x.length === 0) {
  #|         throw new Error('missing Ed25519 public key component');
  #|       }
  #|       return base64UrlToBytes(jwk.x);
  #|     };
  #|     const concatBytes = (...parts) => {
  #|       let total = 0;
  #|       for (const part of parts) total += part.length;
  #|       const out = new Uint8Array(total);
  #|       let offset = 0;
  #|       for (const part of parts) {
  #|         out.set(part, offset);
  #|         offset += part.length;
  #|       }
  #|       return out;
  #|     };
  #|     const uint32be = (value) => new Uint8Array([
  #|       (value >>> 24) & 0xff,
  #|       (value >>> 16) & 0xff,
  #|       (value >>> 8) & 0xff,
  #|       value & 0xff,
  #|     ]);
  #|     const sshString = (value) => {
  #|       const bytes = typeof value === 'string' ? encoder.encode(value) : value;
  #|       return concatBytes(uint32be(bytes.length), bytes);
  #|     };
  #|     const wrapBase64 = (value, width = 70) => {
  #|       const parts = [];
  #|       for (let i = 0; i < value.length; i += width) {
  #|         parts.push(value.slice(i, i + width));
  #|       }
  #|       return parts.join('\n');
  #|     };
  #|     const resolveSshEd25519PublicKey = async (pem, keyComment) => {
  #|       const publicKeyRaw = await exportPublicKeyRaw(pem);
  #|       const publicKeyWire = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(publicKeyRaw),
  #|       );
  #|       const suffix = String(keyComment ?? '').length > 0 ? ` ${String(keyComment)}` : '';
  #|       return `ssh-ed25519 ${encodeBase64(publicKeyWire)}${suffix}`;
  #|     };
  #|     const signGitPayloadSshEd25519 = async (pem, messageText) => {
  #|       const subtle = ensureSubtle();
  #|       const privateKey = await importPrivateKey(pem);
  #|       const publicKeyRaw = await exportPublicKeyRaw(pem);
  #|       const payloadBytes = encoder.encode(String(messageText ?? ''));
  #|       const payloadHash = new Uint8Array(
  #|         await subtle.digest('SHA-512', payloadBytes),
  #|       );
  #|       const signedData = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         sshString('git'),
  #|         sshString(new Uint8Array()),
  #|         sshString('sha512'),
  #|         sshString(payloadHash),
  #|       );
  #|       const rawSignature = new Uint8Array(
  #|         await subtle.sign('Ed25519', privateKey, signedData),
  #|       );
  #|       const publicKeyBlob = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(publicKeyRaw),
  #|       );
  #|       const signatureBlob = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(rawSignature),
  #|       );
  #|       const sshSigBlob = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         uint32be(1),
  #|         sshString(publicKeyBlob),
  #|         sshString('git'),
  #|         sshString(new Uint8Array()),
  #|         sshString('sha512'),
  #|         sshString(signatureBlob),
  #|       );
  #|       return (
  #|         '-----BEGIN SSH SIGNATURE-----\n' +
  #|         wrapBase64(encodeBase64(sshSigBlob)) +
  #|         '\n-----END SSH SIGNATURE-----\n'
  #|       );
  #|     };
  #|     return { resolveSshEd25519PublicKey, signGitPayloadSshEd25519 };
  #|   })();
  #|   return helpers.signGitPayloadSshEd25519(privateKeyPem, payload);
  #| }

///|
extern "js" fn js_webcrypto_ensure_ssh_ed25519_verify_helpers() -> Unit =
  #| () => {
  #|   const existing = globalThis.__bitGitJsSshSigHelpers;
  #|   if (
  #|     existing &&
  #|     typeof existing.resolveSshEd25519PublicKey === 'function' &&
  #|     typeof existing.signGitPayloadSshEd25519 === 'function' &&
  #|     typeof existing.verifyGitPayloadSshEd25519 === 'function'
  #|   ) {
  #|     return;
  #|   }
  #|   globalThis.__bitGitJsSshSigHelpers = (() => {
  #|     const encoder = new TextEncoder();
  #|     const decoder = new TextDecoder();
  #|     const ensureSubtle = () => {
  #|       if (!globalThis.crypto?.subtle) {
  #|         throw new Error('Web Crypto SubtleCrypto is not available');
  #|       }
  #|       return globalThis.crypto.subtle;
  #|     };
  #|     const decodeBase64 = (value) => {
  #|       if (typeof atob === 'function') {
  #|         return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  #|       }
  #|       if (typeof Buffer !== 'undefined') {
  #|         return new Uint8Array(Buffer.from(value, 'base64'));
  #|       }
  #|       throw new Error('base64 decode is not available in this runtime');
  #|     };
  #|     const encodeBase64 = (bytes) => {
  #|       if (typeof btoa === 'function') {
  #|         let text = '';
  #|         for (let i = 0; i < bytes.length; i += 1) {
  #|           text += String.fromCharCode(bytes[i]);
  #|         }
  #|         return btoa(text);
  #|       }
  #|       if (typeof Buffer !== 'undefined') {
  #|         return Buffer.from(bytes).toString('base64');
  #|       }
  #|       throw new Error('base64 encode is not available in this runtime');
  #|     };
  #|     const base64UrlToBytes = (value) => {
  #|       const normalized = String(value ?? '').replace(/-/g, '+').replace(/_/g, '/');
  #|       const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  #|       return decodeBase64(padded);
  #|     };
  #|     const decodePem = (pem) => {
  #|       const body = String(pem ?? '')
  #|         .replace(/-----BEGIN[^-]*-----/, '')
  #|         .replace(/-----END[^-]*-----/, '')
  #|         .replace(/\s+/g, '');
  #|       if (!body) {
  #|         throw new Error('private key PEM is empty');
  #|       }
  #|       return decodeBase64(body);
  #|     };
  #|     const importPrivateKey = async (pem) => {
  #|       return ensureSubtle().importKey(
  #|         'pkcs8',
  #|         decodePem(pem),
  #|         { name: 'Ed25519' },
  #|         true,
  #|         ['sign'],
  #|       );
  #|     };
  #|     const importPublicKeyRaw = async (publicKeyRaw) => {
  #|       return ensureSubtle().importKey(
  #|         'raw',
  #|         publicKeyRaw,
  #|         { name: 'Ed25519' },
  #|         true,
  #|         ['verify'],
  #|       );
  #|     };
  #|     const exportPublicKeyRaw = async (pem) => {
  #|       const privateKey = await importPrivateKey(pem);
  #|       const jwk = await ensureSubtle().exportKey('jwk', privateKey);
  #|       if (typeof jwk?.x !== 'string' || jwk.x.length === 0) {
  #|         throw new Error('missing Ed25519 public key component');
  #|       }
  #|       return base64UrlToBytes(jwk.x);
  #|     };
  #|     const concatBytes = (...parts) => {
  #|       let total = 0;
  #|       for (const part of parts) total += part.length;
  #|       const out = new Uint8Array(total);
  #|       let offset = 0;
  #|       for (const part of parts) {
  #|         out.set(part, offset);
  #|         offset += part.length;
  #|       }
  #|       return out;
  #|     };
  #|     const uint32be = (value) => new Uint8Array([
  #|       (value >>> 24) & 0xff,
  #|       (value >>> 16) & 0xff,
  #|       (value >>> 8) & 0xff,
  #|       value & 0xff,
  #|     ]);
  #|     const readUint32be = (bytes, offset) => {
  #|       if (offset + 4 > bytes.length) {
  #|         throw new Error('truncated sshsig data');
  #|       }
  #|       return (
  #|         ((bytes[offset] << 24) >>> 0) |
  #|         (bytes[offset + 1] << 16) |
  #|         (bytes[offset + 2] << 8) |
  #|         bytes[offset + 3]
  #|       ) >>> 0;
  #|     };
  #|     const sshString = (value) => {
  #|       const bytes = typeof value === 'string' ? encoder.encode(value) : value;
  #|       return concatBytes(uint32be(bytes.length), bytes);
  #|     };
  #|     const readSshString = (bytes, offset) => {
  #|       const length = readUint32be(bytes, offset);
  #|       const start = offset + 4;
  #|       const end = start + length;
  #|       if (end > bytes.length) {
  #|         throw new Error('truncated ssh string');
  #|       }
  #|       return [bytes.slice(start, end), end];
  #|     };
  #|     const wrapBase64 = (value, width = 70) => {
  #|       const parts = [];
  #|       for (let i = 0; i < value.length; i += width) {
  #|         parts.push(value.slice(i, i + width));
  #|       }
  #|       return parts.join('\n');
  #|     };
  #|     const decodeUtf8 = (bytes) => decoder.decode(bytes);
  #|     const bytesEqual = (left, right) => {
  #|       if (left.length !== right.length) {
  #|         return false;
  #|       }
  #|       for (let i = 0; i < left.length; i += 1) {
  #|         if (left[i] !== right[i]) {
  #|           return false;
  #|         }
  #|       }
  #|       return true;
  #|     };
  #|     const normalizeNewlines = (value) =>
  #|       String(value ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  #|     const resolveSshEd25519PublicKey = async (pem, keyComment) => {
  #|       const publicKeyRaw = await exportPublicKeyRaw(pem);
  #|       const publicKeyWire = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(publicKeyRaw),
  #|       );
  #|       const suffix = String(keyComment ?? '').length > 0 ? ` ${String(keyComment)}` : '';
  #|       return `ssh-ed25519 ${encodeBase64(publicKeyWire)}${suffix}`;
  #|     };
  #|     const parsePublicKeyText = (publicKeyText) => {
  #|       const parts = String(publicKeyText ?? '').trim().split(/\s+/);
  #|       if (parts.length < 2 || parts[0] !== 'ssh-ed25519') {
  #|         throw new Error('expected ssh-ed25519 public key text');
  #|       }
  #|       const publicKeyBlob = decodeBase64(parts[1]);
  #|       let offset = 0;
  #|       const [keyTypeBytes, nextOffset] = readSshString(publicKeyBlob, offset);
  #|       offset = nextOffset;
  #|       const keyType = decodeUtf8(keyTypeBytes);
  #|       if (keyType !== 'ssh-ed25519') {
  #|         throw new Error(`unsupported ssh public key type: ${keyType}`);
  #|       }
  #|       const [publicKeyRaw, endOffset] = readSshString(publicKeyBlob, offset);
  #|       if (endOffset !== publicKeyBlob.length) {
  #|         throw new Error('unexpected trailing data in ssh public key');
  #|       }
  #|       return publicKeyRaw;
  #|     };
  #|     const parseSshSignatureArmor = (signatureText) => {
  #|       const begin = '-----BEGIN SSH SIGNATURE-----';
  #|       const end = '-----END SSH SIGNATURE-----';
  #|       const normalized = normalizeNewlines(signatureText).trim();
  #|       if (!normalized.startsWith(begin) || !normalized.endsWith(end)) {
  #|         throw new Error('expected SSH SIGNATURE armor');
  #|       }
  #|       const body = normalized
  #|         .slice(begin.length, normalized.length - end.length)
  #|         .replace(/\s+/g, '');
  #|       if (body.length === 0) {
  #|         throw new Error('empty SSH SIGNATURE body');
  #|       }
  #|       const bytes = decodeBase64(body);
  #|       if (decodeUtf8(bytes.slice(0, 6)) !== 'SSHSIG') {
  #|         throw new Error('invalid SSHSIG magic');
  #|       }
  #|       let offset = 6;
  #|       const version = readUint32be(bytes, offset);
  #|       offset += 4;
  #|       if (version !== 1) {
  #|         throw new Error(`unsupported SSHSIG version: ${version}`);
  #|       }
  #|       const [publicKeyBlob, publicKeyOffset] = readSshString(bytes, offset);
  #|       offset = publicKeyOffset;
  #|       const [namespaceBytes, namespaceOffset] = readSshString(bytes, offset);
  #|       offset = namespaceOffset;
  #|       const [reservedBytes, reservedOffset] = readSshString(bytes, offset);
  #|       offset = reservedOffset;
  #|       const [hashAlgorithmBytes, hashAlgorithmOffset] = readSshString(bytes, offset);
  #|       offset = hashAlgorithmOffset;
  #|       const [signatureBlob, endOffset] = readSshString(bytes, offset);
  #|       offset = endOffset;
  #|       if (offset !== bytes.length) {
  #|         throw new Error('unexpected trailing data in SSH SIGNATURE');
  #|       }
  #|       let keyOffset = 0;
  #|       const [publicKeyTypeBytes, publicKeyTypeOffset] = readSshString(publicKeyBlob, keyOffset);
  #|       keyOffset = publicKeyTypeOffset;
  #|       const [publicKeyRaw, publicKeyEndOffset] = readSshString(publicKeyBlob, keyOffset);
  #|       if (publicKeyEndOffset !== publicKeyBlob.length) {
  #|         throw new Error('unexpected trailing data in SSH signature public key');
  #|       }
  #|       let sigOffset = 0;
  #|       const [signatureTypeBytes, signatureTypeOffset] = readSshString(signatureBlob, sigOffset);
  #|       sigOffset = signatureTypeOffset;
  #|       const [rawSignature, signatureEndOffset] = readSshString(signatureBlob, sigOffset);
  #|       if (signatureEndOffset !== signatureBlob.length) {
  #|         throw new Error('unexpected trailing data in SSH signature blob');
  #|       }
  #|       return {
  #|         namespace: decodeUtf8(namespaceBytes),
  #|         reserved: reservedBytes,
  #|         hashAlgorithm: decodeUtf8(hashAlgorithmBytes).toLowerCase(),
  #|         publicKeyType: decodeUtf8(publicKeyTypeBytes),
  #|         publicKeyRaw,
  #|         signatureType: decodeUtf8(signatureTypeBytes),
  #|         rawSignature,
  #|       };
  #|     };
  #|     const signGitPayloadSshEd25519 = async (pem, messageText) => {
  #|       const subtle = ensureSubtle();
  #|       const privateKey = await importPrivateKey(pem);
  #|       const publicKeyRaw = await exportPublicKeyRaw(pem);
  #|       const payloadBytes = encoder.encode(String(messageText ?? ''));
  #|       const payloadHash = new Uint8Array(
  #|         await subtle.digest('SHA-512', payloadBytes),
  #|       );
  #|       const signedData = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         sshString('git'),
  #|         sshString(new Uint8Array()),
  #|         sshString('sha512'),
  #|         sshString(payloadHash),
  #|       );
  #|       const rawSignature = new Uint8Array(
  #|         await subtle.sign('Ed25519', privateKey, signedData),
  #|       );
  #|       const publicKeyBlob = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(publicKeyRaw),
  #|       );
  #|       const signatureBlob = concatBytes(
  #|         sshString('ssh-ed25519'),
  #|         sshString(rawSignature),
  #|       );
  #|       const sshSigBlob = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         uint32be(1),
  #|         sshString(publicKeyBlob),
  #|         sshString('git'),
  #|         sshString(new Uint8Array()),
  #|         sshString('sha512'),
  #|         sshString(signatureBlob),
  #|       );
  #|       return (
  #|         '-----BEGIN SSH SIGNATURE-----\n' +
  #|         wrapBase64(encodeBase64(sshSigBlob)) +
  #|         '\n-----END SSH SIGNATURE-----\n'
  #|       );
  #|     };
  #|     const verifyGitPayloadSshEd25519 = async (publicKeyText, messageText, signatureText) => {
  #|       const subtle = ensureSubtle();
  #|       const parsedSignature = parseSshSignatureArmor(signatureText);
  #|       if (parsedSignature.namespace !== 'git') {
  #|         return false;
  #|       }
  #|       if (
  #|         parsedSignature.publicKeyType !== 'ssh-ed25519' ||
  #|         parsedSignature.signatureType !== 'ssh-ed25519'
  #|       ) {
  #|         return false;
  #|       }
  #|       const expectedPublicKeyRaw = parsePublicKeyText(publicKeyText);
  #|       if (!bytesEqual(expectedPublicKeyRaw, parsedSignature.publicKeyRaw)) {
  #|         return false;
  #|       }
  #|       const hashAlgorithm = parsedSignature.hashAlgorithm;
  #|       const digestName =
  #|         hashAlgorithm === 'sha512'
  #|           ? 'SHA-512'
  #|           : hashAlgorithm === 'sha256'
  #|             ? 'SHA-256'
  #|             : '';
  #|       if (!digestName) {
  #|         return false;
  #|       }
  #|       const payloadBytes = encoder.encode(String(messageText ?? ''));
  #|       const payloadHash = new Uint8Array(await subtle.digest(digestName, payloadBytes));
  #|       const signedData = concatBytes(
  #|         encoder.encode('SSHSIG'),
  #|         sshString(parsedSignature.namespace),
  #|         sshString(parsedSignature.reserved),
  #|         sshString(hashAlgorithm),
  #|         sshString(payloadHash),
  #|       );
  #|       const publicKey = await importPublicKeyRaw(expectedPublicKeyRaw);
  #|       return subtle.verify(
  #|         'Ed25519',
  #|         publicKey,
  #|         parsedSignature.rawSignature,
  #|         signedData,
  #|       );
  #|     };
  #|     return {
  #|       resolveSshEd25519PublicKey,
  #|       signGitPayloadSshEd25519,
  #|       verifyGitPayloadSshEd25519,
  #|     };
  #|   })();
  #| }

///|
extern "js" fn js_webcrypto_verify_git_payload_ssh_ed25519_impl(
  public_key : String,
  payload : String,
  signature : String,
) -> @js_async.Promise[Bool] =
  #| (publicKey, payload, signature) => {
  #|   return globalThis.__bitGitJsSshSigHelpers.verifyGitPayloadSshEd25519(
  #|     publicKey,
  #|     payload,
  #|     signature,
  #|   );
  #| }

///|
fn js_resolve_git_dir(
  fs : LibJsHostFs,
  root : String,
) -> String raise @bit.GitError {
  let git_path = join_path(root, ".git")
  if fs.is_file(git_path) {
    resolve_gitdir(fs, git_path)
  } else {
    resolve_worktree_git_dir(fs, root)
  }
}

///|
fn js_repo_object_format(fs : LibJsHostFs, git_dir : String) -> String {
  match
    read_config_value(fs, git_dir + "/config", "extensions", "objectformat") {
    Some(raw) => {
      let normalized = config_strip_quotes(raw).to_lower()
      if normalized == "sha256" {
        "sha256"
      } else {
        "sha1"
      }
    }
    None => "sha1"
  }
}

///|
fn js_require_sha1_signing_repo(
  fs : LibJsHostFs,
  git_dir : String,
) -> Unit raise @bit.GitError {
  if js_repo_object_format(fs, git_dir) != "sha1" {
    raise @bit.GitError::InvalidObject(
      "js commit signing only supports sha1 repositories",
    )
  }
}

///|
priv struct JsPreparedCommit {
  git_dir : String
  parent : @bit.ObjectId?
  tree_id : @bit.ObjectId
  entries : Array[IndexEntry]
  committer : String
  timestamp : Int64
  timezone : String
  message : String
  payload : Bytes
}

///|
fn js_prepare_commit(
  fs : LibJsHostFs,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> JsPreparedCommit raise @bit.GitError {
  let actual_git_dir = js_resolve_git_dir(fs, root)
  let parent = resolve_head_commit(fs, actual_git_dir)
  let entries = read_index_entries(fs, actual_git_dir)
  let tree_id = if entries.length() == 0 {
    raise @bit.GitError::InvalidObject("Empty index")
  } else {
    write_tree_from_index(fs, fs, actual_git_dir, entries, missing_ok=true)
  }
  let parents = match parent {
    Some(id) => [id]
    None => []
  }
  let timestamp = timestamp_secs.to_int64()
  let timezone = "+0000"
  let commit = @bit.Commit::new(
    tree_id, parents, author, timestamp, timezone, author, timestamp, timezone, message,
  )
  {
    git_dir: actual_git_dir,
    parent,
    tree_id,
    entries,
    committer: author,
    timestamp,
    timezone,
    message,
    payload: @bit.serialize_commit_content(commit),
  }
}

///|
fn js_commit_payload_text(payload : Bytes) -> String {
  @utf8.decode_lossy(payload[:])
}

///|
async fn js_resolve_ssh_ed25519_public_key_text(
  private_key_pem : String,
  comment : String,
) -> String raise @bit.GitError {
  js_webcrypto_resolve_ssh_ed25519_public_key_impl(private_key_pem, comment).wait() catch {
    err =>
      raise @bit.GitError::InvalidObject(
        "failed to resolve ssh public key from private key: \{err}",
      )
  }
}

///|
async fn js_sign_git_payload_ssh_ed25519_text(
  private_key_pem : String,
  payload : String,
) -> String raise @bit.GitError {
  js_webcrypto_sign_git_payload_ssh_ed25519_impl(private_key_pem, payload).wait() catch {
    err =>
      raise @bit.GitError::InvalidObject(
        "failed to sign git payload with ssh ed25519: \{err}",
      )
  }
}

///|
async fn js_verify_git_payload_ssh_ed25519_text(
  public_key : String,
  payload : String,
  signature : String,
) -> Bool raise @bit.GitError {
  js_webcrypto_ensure_ssh_ed25519_verify_helpers()
  js_webcrypto_verify_git_payload_ssh_ed25519_impl(
    public_key, payload, signature,
  ).wait() catch {
    err =>
      raise @bit.GitError::InvalidObject(
        "failed to verify git payload with ssh ed25519: \{err}",
      )
  }
}

///|
fn js_require_matching_commit_payload(
  expected_payload : String,
  actual_payload : Bytes,
) -> Unit raise @bit.GitError {
  if expected_payload != js_commit_payload_text(actual_payload) {
    raise @bit.GitError::InvalidObject(
      "commit payload changed while signing; rebuild payload and retry",
    )
  }
}

///|
fn js_append_bytes(out : Array[Byte], data : BytesView) -> Unit {
  for b in data {
    out.push(b)
  }
}

///|
fn js_append_utf8(out : Array[Byte], value : String) -> Unit {
  js_append_bytes(out, @utf8.encode(value))
}

///|
fn js_normalize_newlines(value : String) -> String {
  let out = StringBuilder::new()
  let mut saw_cr = false
  for c in value {
    if saw_cr {
      if c == '\n' {
        out.write_char('\n')
        saw_cr = false
        continue
      } else {
        out.write_char('\n')
        saw_cr = false
      }
    }
    if c == '\r' {
      saw_cr = true
    } else {
      out.write_char(c)
    }
  }
  if saw_cr {
    out.write_char('\n')
  }
  out.to_string()
}

///|
fn js_signature_lines(signature : String) -> Array[String] raise @bit.GitError {
  let lines : Array[String] = []
  let normalized = js_normalize_newlines(signature)
  for line_view in normalized.split("\n") {
    lines.push(line_view.to_string())
  }
  while lines.length() > 0 && lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  if lines.length() == 0 {
    raise @bit.GitError::InvalidObject("Empty commit signature")
  }
  lines
}

///|
fn js_find_commit_header_end(payload : Bytes) -> Int raise @bit.GitError {
  let mut i = 0
  while i + 1 < payload.length() {
    if payload[i] == b'\n' && payload[i + 1] == b'\n' {
      return i
    }
    i += 1
  }
  raise @bit.GitError::InvalidObject("Malformed commit payload")
}

///|
fn js_bytes_starts_with(
  data : Bytes,
  start : Int,
  end_ : Int,
  prefix : String,
) -> Bool {
  let prefix_bytes = @utf8.encode(prefix)
  if end_ - start < prefix_bytes.length() {
    return false
  }
  for i in 0..<prefix_bytes.length() {
    if data[start + i] != prefix_bytes[i] {
      return false
    }
  }
  true
}

///|
fn js_collect_line_ranges(data : Bytes) -> Array[(Int, Int, Bool)] {
  let lines : Array[(Int, Int, Bool)] = []
  if data.length() == 0 {
    return lines
  }
  let mut i = 0
  while i < data.length() {
    let start = i
    while i < data.length() && data[i] != b'\n' {
      i += 1
    }
    let end_ = i
    let has_newline = i < data.length() && data[i] == b'\n'
    if has_newline {
      i += 1
    }
    lines.push((start, end_, has_newline))
  }
  lines
}

///|
fn js_copy_line_range(
  data : Bytes,
  out : Array[Byte],
  line : (Int, Int, Bool),
) -> Unit {
  for b in data[line.0:line.1] {
    out.push(b)
  }
  if line.2 {
    out.push(b'\n')
  }
}

///|
fn js_join_signature_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut out = lines.join("\n")
  if !out.has_suffix("\n") {
    out = out + "\n"
  }
  out
}

///|
fn js_extract_commit_signature(data : Bytes) -> (Bytes, String)? {
  let lines = js_collect_line_ranges(data)
  let mut header_end = lines.length()
  let mut sig_start = -1
  let mut sig_end = -1
  let mut prefix_len = 0
  for i in 0..<lines.length() {
    let line = lines[i]
    if line.1 == line.0 {
      header_end = i
      break
    }
    if js_bytes_starts_with(data, line.0, line.1, "gpgsig ") {
      sig_start = i
      prefix_len = 7
      break
    }
    if js_bytes_starts_with(data, line.0, line.1, "gpgsig-sha256 ") {
      sig_start = i
      prefix_len = 14
      break
    }
  }
  if sig_start < 0 {
    return None
  }
  sig_end = sig_start + 1
  while sig_end < header_end {
    let line = lines[sig_end]
    if line.1 > line.0 && data[line.0] == b' ' {
      sig_end += 1
    } else {
      break
    }
  }
  let signature_lines : Array[String] = []
  let first_line = lines[sig_start]
  signature_lines.push(
    @utf8.decode_lossy(
      Bytes::from_array(data[first_line.0 + prefix_len:first_line.1].to_array())[:],
    ),
  )
  for i in (sig_start + 1)..<sig_end {
    let line = lines[i]
    signature_lines.push(
      @utf8.decode_lossy(
        Bytes::from_array(data[line.0 + 1:line.1].to_array())[:],
      ),
    )
  }
  let out : Array[Byte] = []
  for i in 0..<lines.length() {
    if i >= sig_start && i < sig_end {
      continue
    }
    js_copy_line_range(data, out, lines[i])
  }
  Some((Bytes::from_iter(out.iter()), js_join_signature_lines(signature_lines)))
}

///|
fn js_resolve_revision(
  fs : LibJsHostFs,
  root : String,
  spec : String,
) -> @bit.ObjectId raise @bit.GitError {
  let git_dir = js_resolve_git_dir(fs, root)
  match rev_parse(fs, git_dir, spec) {
    Some(id) => id
    None => raise @bit.GitError::InvalidObject("Unknown revision: " + spec)
  }
}

///|
fn js_commit_id_or_empty(id : @bit.ObjectId?) -> String {
  match id {
    Some(value) => value.to_hex()
    None => ""
  }
}

///|
fn js_merge_status_text(status : MergeStatus) -> String {
  match status {
    AlreadyUpToDate => "already_up_to_date"
    FastForward => "fast_forward"
    Merged => "merged"
    Conflicted => "conflicted"
  }
}

///|
fn js_rebase_status_text(status : RebaseStatus) -> String {
  match status {
    RebaseStatus::Complete => "complete"
    RebaseStatus::Conflict => "conflict"
    RebaseStatus::NothingToRebase => "nothing_to_rebase"
  }
}

///|
fn js_cherry_pick_status_text(status : CherryPickStatus) -> String {
  match status {
    CherryPickStatus::Success => "success"
    CherryPickStatus::Conflict => "conflict"
  }
}

///|
fn js_reset_mode_text(mode : String) -> ResetMode raise @bit.GitError {
  match mode {
    "soft" => ResetMode::Soft
    "mixed" => ResetMode::Mixed
    "hard" => ResetMode::Hard
    _ => raise @bit.GitError::InvalidObject("Unknown reset mode: " + mode)
  }
}

///|
fn js_optional_text(value : String) -> String? {
  if value.length() == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn js_convert_merge_result(result : MergeResult) -> JsMergeResult {
  {
    status: js_merge_status_text(result.status),
    commit_id: js_commit_id_or_empty(result.commit_id),
    conflicts: result.conflicts,
  }
}

///|
fn js_convert_rebase_result(result : RebaseResult) -> JsRebaseResult {
  {
    status: js_rebase_status_text(result.status),
    commit_id: js_commit_id_or_empty(result.commit_id),
    conflicts: result.conflicts,
  }
}

///|
fn js_convert_cherry_pick_result(
  result : CherryPickResult,
) -> JsCherryPickResult {
  {
    status: js_cherry_pick_status_text(result.status),
    commit_id: js_commit_id_or_empty(result.commit_id),
    conflicts: result.conflicts,
  }
}

///|
fn js_inject_commit_signature(
  payload : Bytes,
  signature : String,
) -> Bytes raise @bit.GitError {
  let lines = js_signature_lines(signature)
  let header_end = js_find_commit_header_end(payload)
  let out : Array[Byte] = []
  js_append_bytes(out, payload[:header_end + 1])
  js_append_utf8(out, "gpgsig ")
  js_append_utf8(out, lines[0])
  out.push(b'\n')
  for i in 1..<lines.length() {
    js_append_utf8(out, " ")
    js_append_utf8(out, lines[i])
    out.push(b'\n')
  }
  out.push(b'\n')
  js_append_bytes(out, payload[header_end + 2:])
  Bytes::from_iter(out.iter())
}

///|
fn js_finalize_commit(
  fs : LibJsHostFs,
  prepared : JsPreparedCommit,
  payload : Bytes,
) -> @bit.ObjectId raise @bit.GitError {
  let (commit_id, compressed) = @bit.create_object(
    @bit.ObjectType::Commit,
    payload,
  )
  write_object_bytes(fs, prepared.git_dir, commit_id, compressed)
  update_head_ref(fs, fs, prepared.git_dir, commit_id)
  let committer = prepared.committer
  append_head_update_reflogs(
    fs,
    fs,
    prepared.git_dir,
    prepared.parent.unwrap_or(@bit.ObjectId::zero()),
    commit_id,
    if prepared.parent is None {
      "commit (initial): " + worktree_commit_subject(prepared.message)
    } else {
      "commit: " + worktree_commit_subject(prepared.message)
    },
    committer~,
    timestamp=prepared.timestamp,
    timezone=prepared.timezone,
  )
  if prepared.entries.length() > 0 {
    write_index_entries_with_tree(
      fs,
      fs,
      prepared.git_dir,
      prepared.entries,
      prepared.tree_id,
    )
  }
  commit_id
}

///|
pub fn js_git_init(
  host_id : Int,
  root : String,
  default_branch : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => init_repo(fs, root, default_branch~))
}

///|
pub fn js_add_paths(
  host_id : Int,
  root : String,
  paths : Array[String],
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => add_paths(fs, fs, root, paths))
}

///|
pub fn js_status(host_id : Int, root : String) -> Result[Status, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let entries = read_index_entries(fs, git_dir)
    let index_map : Map[String, IndexEntry] = {}
    for entry in entries {
      index_map[entry.path] = entry
    }
    let files = list_working_files(fs, root)
    files.sort()
    let visited : Map[String, Bool] = {}
    let untracked : Array[String] = []
    let unstaged_modified : Array[String] = []
    for rel_path in files {
      visited[rel_path] = true
      match index_map.get(rel_path) {
        Some(index_entry) => {
          let abs_path = join_path(root, rel_path)
          let content = (fs as &@bit.RepoFileSystem).read_file(abs_path) catch {
            _ => continue
          }
          let worktree_id = @bit.hash_blob(content)
          if worktree_id != index_entry.id {
            unstaged_modified.push(rel_path)
          }
        }
        None => untracked.push(rel_path)
      }
    }
    let unstaged_deleted : Array[String] = []
    for entry in entries {
      if visited.get(entry.path) is Some(_) {
        continue
      }
      let abs_path = join_path(root, entry.path)
      if !fs.is_file(abs_path) {
        unstaged_deleted.push(entry.path)
      }
    }
    let staged_index_map : Map[String, IndexEntry] = {}
    for entry in entries {
      staged_index_map[entry.path] = entry
    }
    let staged_modified : Array[String] = []
    let staged_deleted : Array[String] = []
    let skip_worktree_paths : Map[String, Bool] = {}
    collect_staged_changes_from_head(
      fs, git_dir, staged_index_map, skip_worktree_paths, staged_modified, staged_deleted,
    )
    let staged_added : Array[String] = []
    for item in staged_index_map.to_array() {
      let (path, _) = item
      staged_added.push(path)
    }
    staged_added.sort()
    staged_modified.sort()
    staged_deleted.sort()
    unstaged_modified.sort()
    unstaged_deleted.sort()
    untracked.sort()
    {
      staged_added,
      staged_modified,
      staged_deleted,
      unstaged_modified,
      unstaged_deleted,
      untracked,
    }
  })
}

///|
pub fn js_status_porcelain(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  match js_status(host_id, root) {
    Ok(status_result) => Ok(status_porcelain_from(status_result))
    Err(error) => Err(error)
  }
}

///|
pub async fn js_status_text(
  host_id : Int,
  root : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> String raise @bit.GitError {
    status_text(fs, root)
  })
}

///|
pub fn js_status_text_promise(
  host_id : Int,
  root : String,
) -> @js_async.Promise[Result[String, String]] {
  js_export_promise(async fn() { js_status_text(host_id, root) })
}

///|
pub fn js_commit(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    js_finalize_commit(fs, prepared, prepared.payload).to_hex()
  })
}

///|
pub fn js_commit_amend(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  author_timestamp_secs : Int,
  committer : String,
  committer_timestamp_secs : Int,
  timezone : String,
  encoding : String,
  author_timezone : String,
  committer_timezone : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    commit_amend(
      fs,
      fs,
      root,
      message,
      author,
      author_timestamp_secs.to_int64(),
      committer=if committer.length() == 0 { author } else { committer },
      committer_timestamp=committer_timestamp_secs.to_int64(),
      timezone=if timezone.length() == 0 { "+0000" } else { timezone },
      encoding=if encoding.length() == 0 { "UTF-8" } else { encoding },
      author_timezone=js_optional_text(author_timezone),
      committer_timezone=js_optional_text(committer_timezone),
    ).to_hex()
  })
}

///|
pub fn js_build_commit_payload(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    js_commit_payload_text(prepared.payload)
  })
}

///|
pub fn js_commit_signed(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
  signature : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    js_require_sha1_signing_repo(fs, prepared.git_dir)
    let signed_payload = js_inject_commit_signature(prepared.payload, signature)
    js_finalize_commit(fs, prepared, signed_payload).to_hex()
  })
}

///|
pub fn js_commit_signed_checked(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
  expected_payload : String,
  signature : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let prepared = js_prepare_commit(fs, root, message, author, timestamp_secs)
    js_require_sha1_signing_repo(fs, prepared.git_dir)
    js_require_matching_commit_payload(expected_payload, prepared.payload)
    let signed_payload = js_inject_commit_signature(prepared.payload, signature)
    js_finalize_commit(fs, prepared, signed_payload).to_hex()
  })
}

///|
pub async fn js_resolve_ssh_ed25519_public_key(
  private_key_pem : String,
  comment : String,
) -> Result[String, String] {
  js_wrap_error_async(async fn() -> String raise @bit.GitError {
    js_resolve_ssh_ed25519_public_key_text(private_key_pem, comment)
  })
}

///|
pub fn js_resolve_ssh_ed25519_public_key_promise(
  private_key_pem : String,
  comment : String,
) -> @js_async.Promise[Result[String, String]] {
  js_export_promise(async fn() {
    js_resolve_ssh_ed25519_public_key(private_key_pem, comment)
  })
}

///|
pub async fn js_sign_git_payload_ssh_ed25519(
  private_key_pem : String,
  payload : String,
) -> Result[String, String] {
  js_wrap_error_async(async fn() -> String raise @bit.GitError {
    js_sign_git_payload_ssh_ed25519_text(private_key_pem, payload)
  })
}

///|
pub fn js_sign_git_payload_ssh_ed25519_promise(
  private_key_pem : String,
  payload : String,
) -> @js_async.Promise[Result[String, String]] {
  js_export_promise(async fn() {
    js_sign_git_payload_ssh_ed25519(private_key_pem, payload)
  })
}

///|
pub async fn js_verify_git_payload_ssh_ed25519(
  public_key : String,
  payload : String,
  signature : String,
) -> Result[Bool, String] {
  js_wrap_error_async(async fn() -> Bool raise @bit.GitError {
    js_verify_git_payload_ssh_ed25519_text(public_key, payload, signature)
  })
}

///|
pub fn js_verify_git_payload_ssh_ed25519_promise(
  public_key : String,
  payload : String,
  signature : String,
) -> @js_async.Promise[Result[Bool, String]] {
  js_export_promise(async fn() {
    js_verify_git_payload_ssh_ed25519(public_key, payload, signature)
  })
}

///|
pub async fn js_verify_commit_ssh_ed25519(
  host_id : Int,
  root : String,
  spec : String,
  public_key : String,
) -> Result[Bool, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> Bool raise @bit.GitError {
    let git_dir = js_resolve_git_dir(fs, root)
    let commit_id = js_resolve_revision(fs, root, spec)
    let db = ObjectDb::load(fs, git_dir)
    let obj = match db.get(fs, commit_id) {
      Some(value) => value
      None => raise @bit.GitError::InvalidObject("Unknown revision: " + spec)
    }
    if obj.obj_type != @bit.ObjectType::Commit {
      raise @bit.GitError::InvalidObject("Revision is not a commit: " + spec)
    }
    let (payload, signature) = match js_extract_commit_signature(obj.data) {
      Some(value) => value
      None =>
        raise @bit.GitError::InvalidObject(
          "Commit has no gpgsig header: " + spec,
        )
    }
    js_verify_git_payload_ssh_ed25519_text(
      public_key,
      js_commit_payload_text(payload),
      signature,
    )
  })
}

///|
pub fn js_verify_commit_ssh_ed25519_promise(
  host_id : Int,
  root : String,
  spec : String,
  public_key : String,
) -> @js_async.Promise[Result[Bool, String]] {
  js_export_promise(async fn() {
    js_verify_commit_ssh_ed25519(host_id, root, spec, public_key)
  })
}

///|
pub fn js_log(
  host_id : Int,
  root : String,
  max_count : Int,
) -> Result[Array[JsLogEntry], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let entries = log_head(fs, git_dir, max_count~)
    let result : Array[JsLogEntry] = []
    for entry in entries {
      result.push({
        id: entry.id.to_hex(),
        author: entry.author,
        message: entry.message,
        timestamp: entry.timestamp.to_int(),
      })
    }
    result
  })
}

///|
pub fn js_rev_parse(
  host_id : Int,
  root : String,
  spec : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    match rev_parse(fs, git_dir, spec) {
      Some(id) => id.to_hex()
      None => ""
    }
  })
}

///|
pub fn js_show_ref(
  host_id : Int,
  root : String,
) -> Result[Array[JsRefInfo], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let refs = show_ref(fs, git_dir)
    let result : Array[JsRefInfo] = []
    for item in refs {
      let (name, id) = item
      result.push({ name, id: id.to_hex() })
    }
    result
  })
}

///|
pub fn js_merge(
  host_id : Int,
  root : String,
  target : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> Result[JsMergeResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let target_id = js_resolve_revision(fs, root, target)
    let merged = merge(
      fs,
      fs,
      root,
      target_id,
      message,
      author,
      timestamp_secs.to_int64(),
    )
    js_convert_merge_result(merged)
  })
}

///|
pub fn js_checkout(
  host_id : Int,
  root : String,
  target : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => ignore(checkout(fs, fs, root, target)))
}

///|
pub fn js_checkout_b(
  host_id : Int,
  root : String,
  branch_name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    create_branch(fs, fs, root, branch_name)
    ignore(checkout(fs, fs, root, branch_name))
  })
}

///|
pub fn js_switch_branch(
  host_id : Int,
  root : String,
  name : String,
  create : Bool,
  checkout_files : Bool,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    switch_branch(fs, fs, root, name, create~, checkout_files~)
  })
}

///|
pub fn js_restore_paths(
  host_id : Int,
  root : String,
  paths : Array[String],
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => restore_paths(fs, fs, root, paths))
}

///|
pub fn js_branch_list(
  host_id : Int,
  root : String,
) -> Result[Array[JsBranchInfo], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let (_, branches) = list_branches(fs, git_dir)
    let result : Array[JsBranchInfo] = []
    for branch in branches {
      result.push({
        name: branch.name,
        commit_id: branch.id.to_hex(),
        is_current: branch.current,
      })
    }
    result
  })
}

///|
pub fn js_branch_create(
  host_id : Int,
  root : String,
  name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => create_branch(fs, fs, root, name))
}

///|
pub fn js_branch_delete(
  host_id : Int,
  root : String,
  name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => delete_branch(fs, fs, root, name))
}

///|
pub fn js_branch_rename(
  host_id : Int,
  root : String,
  old_name : String,
  new_name : String,
  force : Bool,
  author : String,
  email : String,
  timestamp_secs : Int,
  timezone : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    rename_branch(
      fs,
      fs,
      root,
      old_name,
      new_name,
      force~,
      author~,
      email~,
      timestamp=timestamp_secs.to_int64(),
      timezone~,
    )
  })
}

///|
pub fn js_tag_list(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => list_tags(fs, js_resolve_git_dir(fs, root)))
}

///|
pub fn js_tag_delete(
  host_id : Int,
  root : String,
  name : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => delete_tag(fs, fs, js_resolve_git_dir(fs, root), name))
}

///|
pub fn js_tag_create_lightweight(
  host_id : Int,
  root : String,
  name : String,
  target : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let target_id = js_resolve_revision(fs, root, target)
    create_lightweight_tag(fs, fs, git_dir, name, target_id)
  })
}

///|
pub fn js_tag_create_annotated(
  host_id : Int,
  root : String,
  name : String,
  target : String,
  message : String,
  tagger : String,
  timestamp_secs : Int,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let target_id = js_resolve_revision(fs, root, target)
    create_annotated_tag(
      fs,
      fs,
      git_dir,
      name,
      target_id,
      message,
      tagger,
      timestamp_secs.to_int64(),
    )
  })
}

///|
pub fn js_rebase_start(
  host_id : Int,
  root : String,
  upstream : String,
) -> Result[JsRebaseResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let upstream_id = js_resolve_revision(fs, root, upstream)
    js_convert_rebase_result(rebase_start(fs, fs, root, upstream_id))
  })
}

///|
pub fn js_rebase_start_with_onto(
  host_id : Int,
  root : String,
  onto : String,
  upstream : String,
) -> Result[JsRebaseResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let onto_id = js_resolve_revision(fs, root, onto)
    let upstream_id = js_resolve_revision(fs, root, upstream)
    js_convert_rebase_result(
      rebase_start_with_onto(fs, fs, root, onto_id, upstream_id),
    )
  })
}

///|
pub fn js_rebase_continue(
  host_id : Int,
  root : String,
) -> Result[JsRebaseResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => js_convert_rebase_result(rebase_continue(fs, fs, root)))
}

///|
pub fn js_rebase_abort(host_id : Int, root : String) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => rebase_abort(fs, fs, root))
}

///|
pub fn js_rebase_skip(
  host_id : Int,
  root : String,
) -> Result[JsRebaseResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => js_convert_rebase_result(rebase_skip(fs, fs, root)))
}

///|
pub fn js_reset(
  host_id : Int,
  root : String,
  spec : String,
  mode : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    reset(fs, fs, root, spec, js_reset_mode_text(mode)).to_hex()
  })
}

///|
pub fn js_stash_list(
  host_id : Int,
  root : String,
) -> Result[Array[JsStashEntry], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let git_dir = js_resolve_git_dir(fs, root)
    let entries = stash_list(fs, git_dir)
    let result : Array[JsStashEntry] = []
    for entry in entries {
      result.push({ id: entry.id.to_hex(), message: entry.message })
    }
    result
  })
}

///|
pub async fn js_stash_push(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> String raise @bit.GitError {
    match stash_push(fs, fs, root, message, author, timestamp_secs.to_int64()) {
      Some(id) => id.to_hex()
      None => ""
    }
  })
}

///|
pub fn js_stash_push_promise(
  host_id : Int,
  root : String,
  message : String,
  author : String,
  timestamp_secs : Int,
) -> @js_async.Promise[Result[String, String]] {
  js_export_promise(async fn() {
    js_stash_push(host_id, root, message, author, timestamp_secs)
  })
}

///|
pub fn js_stash_apply(
  host_id : Int,
  root : String,
  index : Int,
  drop : Bool,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => stash_apply(fs, fs, root, index, drop))
}

///|
pub fn js_stash_drop(
  host_id : Int,
  root : String,
  index : Int,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => stash_drop(fs, fs, root, index))
}

///|
pub fn js_cherry_pick(
  host_id : Int,
  root : String,
  target : String,
  author : String,
  timestamp_secs : Int,
  no_commit : Bool,
  message_suffix : String,
  signoff_committer : String,
) -> Result[JsCherryPickResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let target_id = js_resolve_revision(fs, root, target)
    js_convert_cherry_pick_result(
      cherry_pick(
        fs,
        fs,
        root,
        target_id,
        author,
        timestamp_secs.to_int64(),
        no_commit~,
        message_suffix~,
        signoff_committer~,
      ),
    )
  })
}

///|
pub async fn js_diff_worktree(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> Array[String] raise @bit.GitError {
    diff_text(diff_worktree(fs, root))
  })
}

///|
pub fn js_diff_worktree_promise(
  host_id : Int,
  root : String,
) -> @js_async.Promise[Result[Array[String], String]] {
  js_export_promise(async fn() { js_diff_worktree(host_id, root) })
}

///|
pub async fn js_diff_worktree_stat(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> Array[String] raise @bit.GitError {
    diff_stat(diff_worktree(fs, root))
  })
}

///|
pub fn js_diff_worktree_stat_promise(
  host_id : Int,
  root : String,
) -> @js_async.Promise[Result[Array[String], String]] {
  js_export_promise(async fn() { js_diff_worktree_stat(host_id, root) })
}

///|
pub fn js_diff_index(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => diff_text(diff_index(fs, root)))
}

///|
pub fn js_diff_index_stat(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => diff_stat(diff_index(fs, root)))
}

///|
pub fn js_list_remotes(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => list_remotes(fs, js_resolve_git_dir(fs, root)))
}

///|
pub fn js_list_remotes_verbose(
  host_id : Int,
  root : String,
) -> Result[Array[JsRemoteVerboseEntry], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    let entries = list_remotes_verbose(fs, js_resolve_git_dir(fs, root))
    let result : Array[JsRemoteVerboseEntry] = []
    for item in entries {
      let (name, value) = item
      result.push({ name, value })
    }
    result
  })
}

///|
pub fn js_get_remote_url(
  host_id : Int,
  root : String,
  name : String,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    get_remote_url(fs, js_resolve_git_dir(fs, root), name).unwrap_or("")
  })
}

///|
pub fn js_sparse_checkout_init(
  host_id : Int,
  root : String,
  cone : Bool,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => sparse_checkout_init(fs, fs, root, cone~))
}

///|
pub fn js_sparse_checkout_set(
  host_id : Int,
  root : String,
  patterns : Array[String],
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => sparse_checkout_set(fs, fs, root, patterns))
}

///|
pub fn js_sparse_checkout_add(
  host_id : Int,
  root : String,
  patterns : Array[String],
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => sparse_checkout_add(fs, fs, root, patterns))
}

///|
pub fn js_sparse_checkout_disable(
  host_id : Int,
  root : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => sparse_checkout_disable(fs, fs, root))
}

///|
pub fn js_sparse_checkout_reapply(
  host_id : Int,
  root : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => sparse_checkout_reapply(fs, fs, root))
}

///|
pub fn js_sparse_checkout_enabled(
  host_id : Int,
  root : String,
) -> Result[Bool, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    is_sparse_checkout_enabled(fs, js_resolve_git_dir(fs, root))
  })
}

///|
pub fn js_sparse_checkout_cone_enabled(
  host_id : Int,
  root : String,
) -> Result[Bool, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    is_sparse_checkout_cone_enabled(fs, js_resolve_git_dir(fs, root))
  })
}

///|
pub fn js_sparse_checkout_patterns(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => read_sparse_patterns(fs, js_resolve_git_dir(fs, root)))
}

///|
pub fn js_sparse_checkout_display_patterns(
  host_id : Int,
  root : String,
) -> Result[Array[String], String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => {
    read_sparse_display_patterns(fs, js_resolve_git_dir(fs, root))
  })
}

///|
fn js_normalize_push_refname(refname : String) -> String raise @bit.GitError {
  let normalized = normalize_repo_path(refname) catch {
    _ => raise @bit.GitError::InvalidObject("invalid refname: " + refname)
  }
  if normalized.has_prefix("refs/") {
    normalized
  } else {
    "refs/heads/" + normalized
  }
}

///|
fn js_default_push_refname(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> String raise @bit.GitError {
  match read_head_ref(rfs, git_dir) {
    HeadRef::Branch(name) => "refs/heads/" + name
    HeadRef::Detached(_) =>
      raise @bit.GitError::InvalidObject(
        "refname is required when HEAD is detached",
      )
  }
}

///|
fn js_head_refname(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
) -> String raise @bit.GitError {
  match read_head_ref(rfs, git_dir) {
    HeadRef::Branch(name) => "refs/heads/" + name
    HeadRef::Detached(_) => "HEAD"
  }
}

///|
fn js_find_remote_ref(
  refs : Array[(@bit.ObjectId, String)],
  refname : String,
) -> @bit.ObjectId {
  for item in refs {
    let (id, current_refname) = item
    if current_refname == refname {
      return id
    }
  }
  @bit.ObjectId::zero()
}

///|
fn js_is_ancestor(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  base : @bit.ObjectId,
  target : @bit.ObjectId,
) -> Bool raise @bit.GitError {
  let db = ObjectDb::load(rfs, git_dir)
  let mut current = target
  while true {
    if current == base {
      return true
    }
    let obj = db.get(rfs, current)
    match obj {
      None => return false
      Some(value) => {
        if value.obj_type != @bit.ObjectType::Commit {
          return false
        }
        let info = @bit.parse_commit(value.data)
        if info.parents.length() == 0 {
          return false
        }
        current = info.parents[0]
      }
    }
  }
  false
}

///|
fn js_remote_tracking_refname(refname : String) -> String raise @bit.GitError {
  let normalized = normalize_repo_path(refname) catch {
    _ => raise @bit.GitError::InvalidObject("invalid refname: " + refname)
  }
  if normalized.has_prefix("refs/heads/") {
    let name = String::unsafe_substring(
      normalized,
      start=11,
      end=normalized.length(),
    )
    "refs/remotes/origin/" + name
  } else if normalized == "HEAD" {
    "refs/remotes/origin/HEAD"
  } else if normalized.has_prefix("refs/") {
    "refs/remotes/origin/" + normalized
  } else {
    raise @bit.GitError::InvalidObject("invalid refname: " + refname)
  }
}

///|
fn js_format_fetch_head_description(
  source_refname : String?,
  remote_url : String,
) -> String {
  match source_refname {
    Some(refname) if refname.has_prefix("refs/heads/") => {
      let branch = String::unsafe_substring(
        refname,
        start=11,
        end=refname.length(),
      )
      "branch '" + branch + "' of " + remote_url
    }
    Some(refname) if refname.has_prefix("refs/tags/") => {
      let tag = String::unsafe_substring(
        refname,
        start=10,
        end=refname.length(),
      )
      "tag '" + tag + "' of " + remote_url
    }
    Some(refname) => refname + " of " + remote_url
    None => remote_url
  }
}

///|
fn js_select_fetch_target(
  refs : Array[(@bit.ObjectId, String)],
  symrefs : Map[String, String],
  refspec : String,
) -> (String, @bit.ObjectId)? raise @bit.GitError {
  if refspec.length() == 0 {
    match @protocol.select_default_ref(refs, symrefs) {
      Some((refname, id)) => return Some((refname, id))
      None => return None
    }
  }
  let candidates : Array[String] = []
  let normalized = normalize_repo_path(refspec) catch {
    _ => raise @bit.GitError::InvalidObject("invalid refspec: " + refspec)
  }
  if normalized == "HEAD" {
    candidates.push("HEAD")
    match symrefs.get("HEAD") {
      Some(target) => candidates.push(target)
      None => ()
    }
  } else if normalized.has_prefix("refs/") {
    candidates.push(normalized)
  } else {
    candidates.push("refs/heads/" + normalized)
    candidates.push("refs/tags/" + normalized)
    candidates.push(normalized)
  }
  for candidate in candidates {
    for item in refs {
      let (id, refname) = item
      if refname == candidate {
        return Some((refname, id))
      }
    }
  }
  None
}

///|
fn js_branch_name_from_refname(refname : String) -> String? {
  if refname.has_prefix("refs/heads/") {
    Some(String::unsafe_substring(refname, start=11, end=refname.length()))
  } else {
    None
  }
}

///|
fn js_default_clone_branch(
  refs : Array[(@bit.ObjectId, String)],
  symrefs : Map[String, String],
) -> String {
  match symrefs.get("HEAD") {
    Some(target) =>
      match js_branch_name_from_refname(target) {
        Some(branch) => return branch
        None => ()
      }
    None => ()
  }
  for item in refs {
    let (_, refname) = item
    match js_branch_name_from_refname(refname) {
      Some(branch) => return branch
      None => ()
    }
  }
  "main"
}

///|
fn js_write_clone_remote_config(
  fs : LibJsHostFs,
  git_dir : String,
  remote_url : String,
) -> Unit raise @bit.GitError {
  set_config_key(fs, fs, git_dir, "remote", "origin", "url", remote_url)
  set_config_key(
    fs, fs, git_dir, "remote", "origin", "fetch", "+refs/heads/*:refs/remotes/origin/*",
  )
}

///|
fn js_set_clone_branch_tracking(
  fs : LibJsHostFs,
  git_dir : String,
  branch : String,
) -> Unit raise @bit.GitError {
  set_config_key(fs, fs, git_dir, "branch", branch, "remote", "origin")
  set_config_key(
    fs,
    fs,
    git_dir,
    "branch",
    branch,
    "merge",
    "refs/heads/" + branch,
  )
}

///|
fn js_write_clone_remote_tracking_ref(
  fs : LibJsHostFs,
  git_dir : String,
  refname : String,
  commit_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  match js_branch_name_from_refname(refname) {
    Some(branch) => {
      let remote_ref = "refs/remotes/origin/" + branch
      let remote_ref_path = join_path(git_dir, remote_ref)
      fs.mkdir_p(rebase_parent_dir(remote_ref_path))
      fs.write_string(remote_ref_path, commit_id.to_hex() + "\n")
      let remote_head_path = join_path(git_dir, "refs/remotes/origin/HEAD")
      fs.mkdir_p(rebase_parent_dir(remote_head_path))
      fs.write_string(remote_head_path, "ref: " + remote_ref + "\n")
      js_set_clone_branch_tracking(fs, git_dir, branch)
    }
    None => ()
  }
}

///|
pub async fn js_clone_remote(
  host_id : Int,
  root : String,
  remote_url : String,
  transport_id : Int,
  prefer_v2 : Bool,
) -> Result[JsCloneResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> JsCloneResult raise @bit.GitError {
    let (refs, _caps, _version, symrefs) = @bitnative.discover_upload_refs_with_http(
      remote_url,
      prefer_v2,
      async fn(
        url : String,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        js_transport_get(transport_id, url, headers)
      },
      async fn(
        url : String,
        body : Bytes,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        js_transport_post(transport_id, url, body, headers)
      },
    )
    let wants = @protocol.select_default_wants(refs, symrefs)
    let default_ref = @protocol.select_default_ref(refs, symrefs)
    match default_ref {
      None => {
        let default_branch = js_default_clone_branch(refs, symrefs)
        init_repo(fs, root, default_branch~)
        let git_dir = js_resolve_git_dir(fs, root)
        js_write_clone_remote_config(fs, git_dir, remote_url)
        js_set_clone_branch_tracking(fs, git_dir, default_branch)
      }
      Some((refname, commit_id)) => {
        if wants.length() > 0 {
          let pack = @bitnative.fetch_pack_with_http(
            remote_url,
            wants,
            prefer_v2,
            0,
            @protocol.FilterSpec::NoFilter,
            async fn(
              url : String,
              headers : Map[String, String],
            ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
              js_transport_get(transport_id, url, headers)
            },
            async fn(
              url : String,
              body : Bytes,
              headers : Map[String, String],
            ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
              js_transport_post(transport_id, url, body, headers)
            },
          )
          let objects = @pack.parse_packfile(pack)
          let git_dir = join_path(root, ".git")
          fs.mkdir_p(join_path(git_dir, "objects/pack"))
          @pack.write_packfile_with_index(fs, git_dir, pack, objects)
          let store = @bit.ObjectStore::from_pack(objects)
          @bit.materialize_clone_to_fs(
            store, commit_id, refname, remote_url, fs, root,
          )
        } else {
          init_repo(
            fs,
            root,
            default_branch=js_default_clone_branch(refs, symrefs),
          )
        }
        let git_dir = js_resolve_git_dir(fs, root)
        js_write_clone_remote_config(fs, git_dir, remote_url)
        js_write_clone_remote_tracking_ref(fs, git_dir, refname, commit_id)
      }
    }
    let git_dir = js_resolve_git_dir(fs, root)
    let commit_id = resolve_head_commit(fs, git_dir)
    {
      status: if commit_id is Some(_) {
        "cloned"
      } else {
        "empty"
      },
      commit_id: js_commit_id_or_empty(commit_id),
      refname: js_head_refname(fs, git_dir),
    }
  })
}

///|
pub fn js_clone_remote_promise(
  host_id : Int,
  root : String,
  remote_url : String,
  transport_id : Int,
  prefer_v2 : Bool,
) -> @js_async.Promise[Result[JsCloneResult, String]] {
  js_export_promise(async fn() {
    js_clone_remote(host_id, root, remote_url, transport_id, prefer_v2)
  })
}

///|
pub async fn js_fetch_remote(
  host_id : Int,
  root : String,
  remote_url : String,
  transport_id : Int,
  refspec : String,
  prefer_v2 : Bool,
) -> Result[JsFetchResult, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> JsFetchResult raise @bit.GitError {
    let git_dir = js_resolve_git_dir(fs, root)
    let (refs, _caps, _version, symrefs) = @bitnative.discover_upload_refs_with_http(
      remote_url,
      prefer_v2,
      async fn(
        url : String,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        js_transport_get(transport_id, url, headers)
      },
      async fn(
        url : String,
        body : Bytes,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        js_transport_post(transport_id, url, body, headers)
      },
    )
    match js_select_fetch_target(refs, symrefs, refspec) {
      None => { status: "empty", commit_id: "", refname: "", remote_ref: "" }
      Some((refname, commit_id)) => {
        let pack = @bitnative.fetch_pack_with_http(
          remote_url,
          [commit_id],
          prefer_v2,
          0,
          @protocol.FilterSpec::NoFilter,
          async fn(
            url : String,
            headers : Map[String, String],
          ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
            js_transport_get(transport_id, url, headers)
          },
          async fn(
            url : String,
            body : Bytes,
            headers : Map[String, String],
          ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
            js_transport_post(transport_id, url, body, headers)
          },
        )
        let objects = @pack.parse_packfile(pack)
        fs.mkdir_p(join_path(git_dir, "objects/pack"))
        @pack.write_packfile_with_index(fs, git_dir, pack, objects)
        let remote_ref = js_remote_tracking_refname(refname)
        let remote_ref_path = join_path(git_dir, remote_ref)
        fs.mkdir_p(rebase_parent_dir(remote_ref_path))
        fs.write_string(remote_ref_path, commit_id.to_hex() + "\n")
        fs.write_string(
          join_path(git_dir, "FETCH_HEAD"),
          commit_id.to_hex() +
          "\t\t" +
          js_format_fetch_head_description(Some(refname), remote_url) +
          "\n",
        )
        {
          status: "fetched",
          commit_id: commit_id.to_hex(),
          refname,
          remote_ref,
        }
      }
    }
  })
}

///|
pub fn js_fetch_remote_promise(
  host_id : Int,
  root : String,
  remote_url : String,
  transport_id : Int,
  refspec : String,
  prefer_v2 : Bool,
) -> @js_async.Promise[Result[JsFetchResult, String]] {
  js_export_promise(async fn() {
    js_fetch_remote(host_id, root, remote_url, transport_id, refspec, prefer_v2)
  })
}

///|
pub async fn js_push_remote(
  host_id : Int,
  root : String,
  remote_url : String,
  transport_id : Int,
  refname : String,
  force : Bool,
) -> Result[String, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error_async(async fn() -> String raise @bit.GitError {
    let git_dir = js_resolve_git_dir(fs, root)
    let head = resolve_head_commit(fs, git_dir)
    guard head is Some(head_id) else {
      raise @bit.GitError::InvalidObject("HEAD not found")
    }
    let target_ref = if refname.length() == 0 {
      js_default_push_refname(fs, git_dir)
    } else {
      js_normalize_push_refname(refname)
    }
    let db = ObjectDb::load(fs, git_dir)
    let objects = collect_reachable_objects(db, fs, head_id)
    let pack = @pack.create_packfile(objects)
    let remote = @protocol.Remote::new(remote_url)
    let (refs, _caps) = @protocol.discover_refs_with_http(remote, async fn(
      url : String,
      headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      js_transport_get(transport_id, url, headers)
    })
    let old_id = js_find_remote_ref(refs, target_ref)
    if !force && old_id != @bit.ObjectId::zero() {
      if !js_is_ancestor(fs, git_dir, old_id, head_id) {
        raise @bit.GitError::InvalidObject(
          "Updates were rejected because the tip of your current branch is behind its remote counterpart. Use force to override.",
        )
      }
    }
    let req = @protocol.PushRequest::new(old_id, head_id, target_ref, pack)
    @protocol.push_with_http(
      remote,
      req,
      async fn(
        url : String,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        js_transport_get(transport_id, url, headers)
      },
      async fn(
        url : String,
        body : Bytes,
        headers : Map[String, String],
      ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
        js_transport_post(transport_id, url, body, headers)
      },
    )
  })
}

///|
pub fn js_push_remote_promise(
  host_id : Int,
  root : String,
  remote_url : String,
  transport_id : Int,
  refname : String,
  force : Bool,
) -> @js_async.Promise[Result[String, String]] {
  js_export_promise(async fn() {
    js_push_remote(host_id, root, remote_url, transport_id, refname, force)
  })
}

///|
pub fn js_rm_paths(
  host_id : Int,
  root : String,
  paths : Array[String],
  cached : Bool,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => rm_paths(fs, fs, root, paths, cached~))
}

///|
pub fn js_mv_path(
  host_id : Int,
  root : String,
  source : String,
  dest : String,
) -> Result[Unit, String] {
  let fs = js_make_host_fs(host_id)
  js_wrap_error(() => mv_path(fs, fs, root, source, dest))
}
