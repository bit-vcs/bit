///|
async test "upload-pack wasm remote: direct api errors without configured client" {
  clear_wasm_http_client()
  let result : Result[Bytes, Error] = try? upload_pack_info_refs(
    "https://github.com/user/repo.git", true,
  )
  match result {
    Err(@bit.GitError::ProtocolError(msg)) =>
      assert_true(msg.contains("configure_wasm_http_client"))
    _ => assert_true(false)
  }
}

///|
async test "upload-pack wasm remote: clone-to-fs uses configured client" {
  let adv = upload_pack_http_hex_to_bytes(upload_pack_http_adv_v2_hex)
  let lsrefs = upload_pack_http_hex_to_bytes(upload_pack_http_lsrefs_hex)
  let fetch = upload_pack_http_hex_to_bytes(upload_pack_http_fetch_hex)
  let fs = @bit.TestFs::new()
  configure_wasm_http_client(
    async fn(
      _url : String,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      let no_ops : Array[async () -> Unit] = []
      ignore(
        @async.all(no_ops) catch {
          err => raise @bit.GitError::IoError(err.to_string())
        },
      )
      (@bit.HttpResponse::new(200), adv)
    },
    async fn(
      _url : String,
      body : Bytes,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      let no_ops : Array[async () -> Unit] = []
      ignore(
        @async.all(no_ops) catch {
          err => raise @bit.GitError::IoError(err.to_string())
        },
      )
      let text = upload_pack_http_bytes_to_string(body)
      if text.contains("command=ls-refs") {
        return (@bit.HttpResponse::new(200), lsrefs)
      }
      if text.contains("command=fetch") || text.contains("want ") {
        return (@bit.HttpResponse::new(200), fetch)
      }
      raise @bit.GitError::ProtocolError("unexpected request body")
    },
  )
  let refs = clone_remote_to_fs(
    "git@github.com:user/repo.git", true, fs, "/repo",
  )
  assert_true(refs.length() > 0)
  assert_eq(fs.read_string("/repo/hello.txt"), "hello\n")
  assert_eq(fs.read_string("/repo/.git/HEAD"), "ref: refs/heads/main\n")
  clear_wasm_http_client()
}
