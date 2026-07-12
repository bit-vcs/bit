///| Native OpenPGP detached-signature verification.
///
/// Thin wrapper over `mizchi/experimental_crypto/pgp` that lets `bit` verify
/// OpenPGP signatures (commits, tags) without shelling out to `gpg`. The
/// caller supplies the signed payload, the ASCII-armored detached signature,
/// and one or more ASCII-armored public keys to check against.

///|
/// Outcome of an OpenPGP verification attempt.
pub struct VerifyResult {
  /// True when at least one supplied public key validates the signature.
  verified : Bool
  /// Set when no key validated and a parse/verify error was encountered for
  /// every candidate (best-effort diagnostic; `None` for a clean "bad
  /// signature" where the keys parsed but none matched).
  error : String?
}

///|
/// Verify a detached, ASCII-armored OpenPGP signature over `payload` against a
/// set of ASCII-armored public keys. Returns `verified = true` as soon as any
/// key validates the signature. Keys that fail to parse, or signature schemes
/// the underlying library does not support, are skipped rather than aborting
/// the whole check, so a single bad key in the file cannot mask a good one.
pub fn verify_detached_armored(
  payload : Bytes,
  signature_armor : String,
  public_keys_armor : Array[String],
) -> VerifyResult {
  let mut last_error : String? = None
  for key_armor in public_keys_armor {
    let packet = @pgp.parse_pubkey_armor(key_armor) catch {
      _ => {
        last_error = Some("failed to parse OpenPGP public key")
        continue
      }
    }
    let ok = @pgp.verify_armor(signature_armor, payload, packet.key) catch {
      _ => {
        last_error = Some("unsupported or malformed OpenPGP signature")
        continue
      }
    }
    if ok {
      return { verified: true, error: None }
    }
  }
  { verified: false, error: last_error }
}

///|
/// Verify a detached SSHSIG (`-----BEGIN SSH SIGNATURE-----`) signature over
/// `payload` against an OpenSSH allowed-signers file (the contents of
/// `gpg.ssh.allowedSignersFile`). Git always signs with the `git` namespace,
/// so that is what is enforced here. Returns `verified = true` as soon as any
/// principal listed in the allowed-signers file validates the signature —
/// mirroring `ssh-keygen -Y find-principals` followed by `-Y verify`.
pub fn verify_ssh_detached(
  payload : Bytes,
  signature_armor : String,
  allowed_signers_text : String,
) -> VerifyResult {
  let signers = @ssh.parse_allowed_signers(allowed_signers_text) catch {
    _ =>
      return { verified: false, error: Some("failed to parse allowed signers") }
  }
  let mut last_error : String? = None
  for signer in signers {
    for principal in signer.principals {
      let ok = @ssh.verify_with_allowed_signers(
        allowed_signers_text,
        principal,
        signature_armor,
        payload,
        sig_namespace="git",
      ) catch {
        _ => {
          last_error = Some("unsupported or malformed SSH signature")
          continue
        }
      }
      if ok {
        return { verified: true, error: None }
      }
    }
  }
  { verified: false, error: last_error }
}

///|
/// Split a blob that may contain several concatenated ASCII-armored public key
/// blocks (e.g. a keyring file exported with `gpg --armor --export`) into the
/// individual armored blocks. Whitespace/comments between blocks are ignored.
pub fn split_armored_public_keys(text : String) -> Array[String] {
  let begin = "-----BEGIN PGP PUBLIC KEY BLOCK-----"
  let end = "-----END PGP PUBLIC KEY BLOCK-----"
  let blocks : Array[String] = []
  let mut remaining = text
  while true {
    let start = match remaining.find(begin) {
      Some(i) => i
      None => break
    }
    let from_begin = String::unsafe_substring(
      remaining,
      start~,
      end=remaining.length(),
    )
    let end_off = match from_begin.find(end) {
      Some(i) => i
      None => break
    }
    let block_end = end_off + end.length()
    blocks.push(String::unsafe_substring(from_begin, start=0, end=block_end))
    remaining = String::unsafe_substring(
      from_begin,
      start=block_end,
      end=from_begin.length(),
    )
  }
  blocks
}
