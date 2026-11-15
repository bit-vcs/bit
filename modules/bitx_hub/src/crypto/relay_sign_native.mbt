///| Native relay signing: openssl CLI + C FFI.

///|
extern "C" fn relay_native_time(ptr : Int) -> Int64 = "time"

///|
pub fn relay_unix_timestamp_sec() -> Int64 {
  relay_native_time(0)
}

///|
fn relay_sign_private_key_file() -> String? {
  match @env.get_env_var("BIT_RELAY_SIGN_PRIVATE_KEY_FILE") {
    Some(value) => {
      let normalized = value.trim(chars=" \n\r\t").to_owned()
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
fn relay_sign_public_key() -> String? {
  match @env.get_env_var("BIT_RELAY_SIGN_PUBLIC_KEY") {
    Some(value) => {
      let normalized = value.trim(chars=" \n\r\t").to_owned()
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
pub fn relay_load_signing_key() -> String? {
  relay_sign_private_key_file()
}

///|
/// A shared stdin pipe pre-filled with `text`. The caller passes it as
/// `stdin=Shared(...)` and closes it once the child has been started.
async fn relay_prepare_process_stdin(
  text : String,
) -> @process.SharedProcessInput raise @bit.GitError {
  let (stdin, writer) = @process.write_to_process() catch {
    err => raise @bit.GitError::IoError("relay sign: pipe failed: \{err}")
  }
  writer.write(@utf8.encode(text)) catch {
    err => raise @bit.GitError::IoError("relay sign: pipe write failed: \{err}")
  }
  writer.close()
  stdin
}

///|
pub async fn relay_sha256_hex(text : String) -> String raise @bit.GitError {
  let stdin = relay_prepare_process_stdin(text)
  let proc_result = @process.run(
    "openssl",
    ["dgst", "-sha256", "-hex", "-r"],
    inherit_env=true,
    stdin=Shared(stdin),
    stdout=Collect,
    stderr=Collect,
  ) catch {
    err => {
      stdin.close()
      raise @bit.GitError::IoError("relay sign: openssl dgst failed: \{err}")
    }
  }
  stdin.close()
  let (code, stdout, stderr) = (proc_result.exit_code, proc_result.stdout_binary(), proc_result.stderr_binary())
  if code != 0 {
    let err_text = @utf8.decode(stderr) catch { _ => "" }
    let normalized = err_text.trim(chars=" \n\r\t").to_owned()
    raise @bit.GitError::IoError(
      "relay sign: openssl dgst error: \{normalized}",
    )
  }
  let out_text = @utf8.decode(stdout) catch { _ => "" }
  match relay_extract_sha256_hex(out_text) {
    Some(hex) => hex
    None =>
      raise @bit.GitError::IoError(
        "relay sign: openssl dgst returned unexpected output",
      )
  }
}

///|
pub async fn relay_sign_ed25519(
  key_source : String,
  message : String,
) -> String raise @bit.GitError {
  let tmp_in = "/tmp/bit-relay-sign-in-" +
    @env.now().to_int().to_string() +
    ".bin"
  let message_stdin = relay_prepare_process_stdin(message)
  let write_code = @process.run(
    "sh",
    ["-c", "cat > \"$BIT_SIGN_TMP\""],
    inherit_env=true,
    stdin=Shared(message_stdin),
    extra_env={ "BIT_SIGN_TMP": tmp_in },
  ).exit_code catch {
    err =>
      raise @bit.GitError::IoError(
        "relay sign: failed to write temp file: \{err}",
      )
  }
  message_stdin.close()
  if write_code != 0 {
    raise @bit.GitError::IoError("relay sign: failed to write temp file")
  }
  let proc_result = @process.run(
    "sh",
    [
      "-c", "openssl pkeyutl -sign -rawin -inkey \"$BIT_RELAY_SIGN_PRIVATE_KEY_FILE\" -in \"$BIT_SIGN_TMP\" | openssl base64 -A; rm -f \"$BIT_SIGN_TMP\"",
    ],
    inherit_env=true,
    extra_env={
      "BIT_RELAY_SIGN_PRIVATE_KEY_FILE": key_source,
      "BIT_SIGN_TMP": tmp_in,
    },
    stdout=Collect,
    stderr=Collect,
  ) catch {
    err => {
      ignore(
        @process.run("rm", ["-f", tmp_in], inherit_env=true).exit_code catch {
          _ => -1
        },
      )
      raise @bit.GitError::IoError("relay sign: openssl pkeyutl failed: \{err}")
    }
  }
  let (code, stdout, stderr) = (proc_result.exit_code, proc_result.stdout_binary(), proc_result.stderr_binary())
  if code != 0 {
    let err_text = @utf8.decode(stderr) catch { _ => "" }
    let normalized = err_text.trim(chars=" \n\r\t").to_owned()
    raise @bit.GitError::IoError(
      "relay sign: openssl pkeyutl error: \{normalized}",
    )
  }
  let base64_sig = @utf8.decode(stdout) catch { _ => "" }
  let normalized = base64_sig.trim(chars=" \n\r\t").to_owned()
  if normalized.length() == 0 {
    raise @bit.GitError::IoError("relay sign: openssl produced empty signature")
  }
  relay_base64_to_base64url(normalized)
}

///|
pub async fn relay_resolve_public_key(
  key_source : String,
) -> String raise @bit.GitError {
  match relay_sign_public_key() {
    Some(explicit) => explicit
    None => {
      let proc_result = @process.run(
        "sh",
        [
          "-c", "openssl pkey -in \"$BIT_RELAY_SIGN_PRIVATE_KEY_FILE\" -pubout -outform DER | openssl base64 -A",
        ],
        inherit_env=true,
        extra_env={ "BIT_RELAY_SIGN_PRIVATE_KEY_FILE": key_source },
        stdout=Collect,
        stderr=Collect,
      ) catch {
        err =>
          raise @bit.GitError::IoError(
            "relay sign: openssl pkey failed: \{err}",
          )
      }
      let (code, stdout, stderr) = (proc_result.exit_code, proc_result.stdout_binary(), proc_result.stderr_binary())
      if code != 0 {
        let err_text = @utf8.decode(stderr) catch { _ => "" }
        let normalized = err_text.trim(chars=" \n\r\t").to_owned()
        raise @bit.GitError::IoError(
          "relay sign: openssl pkey error: \{normalized}",
        )
      }
      let der_base64 = @utf8.decode(stdout) catch { _ => "" }
      let normalized = der_base64.trim(chars=" \n\r\t").to_owned()
      if normalized.length() == 0 {
        raise @bit.GitError::IoError(
          "relay sign: openssl returned empty public key",
        )
      }
      let der = @base64.decode(normalized) catch {
        _ =>
          raise @bit.GitError::IoError(
            "relay sign: invalid base64 from openssl public key",
          )
      }
      match relay_extract_ed25519_public_key_from_der(der) {
        Some(key) => key
        None =>
          raise @bit.GitError::IoError(
            "relay sign: unsupported public key format (expected Ed25519)",
          )
      }
    }
  }
}
