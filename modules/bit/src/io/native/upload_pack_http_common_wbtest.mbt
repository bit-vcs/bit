///|
async test "upload-pack http common: info-refs accepts scp-style ssh remote" {
  let mut observed_url = ""
  let result = upload_pack_info_refs_with_http(
    "git@github.com:mizchi/bit-vcs.git",
    true,
    async fn(
      url : String,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      let no_ops : Array[async () -> Unit] = []
      ignore(
        @async.all(no_ops) catch {
          err => raise @bit.GitError::IoError(err.to_string())
        },
      )
      observed_url = url
      (@bit.HttpResponse::new(200), @utf8.encode("ok"))
    },
  )
  assert_eq(
    observed_url, "https://github.com/mizchi/bit-vcs/info/refs?service=git-upload-pack",
  )
  assert_eq(result, @utf8.encode("ok"))
}

///|
async test "upload-pack http common: request accepts ssh:// remote with port" {
  let mut observed_url = ""
  let mut observed_body = @utf8.encode("")
  let result = upload_pack_request_with_http(
    "ssh://git@github.com:2222/mizchi/bit-vcs.git",
    @utf8.encode("body"),
    true,
    async fn(
      url : String,
      body : Bytes,
      _headers : Map[String, String],
    ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
      let no_ops : Array[async () -> Unit] = []
      ignore(
        @async.all(no_ops) catch {
          err => raise @bit.GitError::IoError(err.to_string())
        },
      )
      observed_url = url
      observed_body = body
      (@bit.HttpResponse::new(200), @utf8.encode("resp"))
    },
  )
  assert_eq(observed_url, "https://github.com/mizchi/bit-vcs/git-upload-pack")
  assert_eq(observed_body, @utf8.encode("body"))
  assert_eq(result, @utf8.encode("resp"))
}
