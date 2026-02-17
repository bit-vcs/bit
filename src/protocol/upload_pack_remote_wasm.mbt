///| Upload-pack dispatcher (wasm targets)

///| For wasm, use *_with_http functions from upload_pack_http_common.mbt

///| with your own HTTP client implementation.

///|
fn[T] wasm_http_not_available() -> T raise @bit.GitError {
  raise @bit.GitError::ProtocolError(
    "HTTP client not available on wasm target. Use *_with_http functions with your own HTTP implementation.",
  )
}

///|
async fn[T] wasm_http_not_available_async() -> T raise @bit.GitError {
  @async.sleep(0) catch {
    _ => ()
  }
  wasm_http_not_available()
}

///|
pub async fn upload_pack_info_refs(
  _remote : String,
  _prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  wasm_http_not_available_async()
}

///|
pub async fn upload_pack_request(
  _remote : String,
  _body : Bytes,
  _prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  wasm_http_not_available_async()
}

///|
pub async fn discover_upload_refs(
  _remote : String,
  _prefer_v2 : Bool,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  wasm_http_not_available_async()
}

///|
pub async fn fetch_pack(
  _remote : String,
  _wants : Array[@bit.ObjectId],
  _prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  wasm_http_not_available_async()
}

///|
pub async fn fetch_objects(
  _remote : String,
  _wants : Array[@bit.ObjectId],
  _prefer_v2 : Bool,
) -> Array[@bit.PackObject] raise @bit.GitError {
  wasm_http_not_available_async()
}

///|
pub async fn clone_remote(
  _remote : String,
  _prefer_v2 : Bool,
) -> (Array[(@bit.ObjectId, String)], Array[@bit.PackObject]) raise @bit.GitError {
  wasm_http_not_available_async()
}

///|
pub async fn clone_remote_to_fs(
  _remote : String,
  _prefer_v2 : Bool,
  _fs : &@bit.FileSystem,
  _root : String,
) -> Array[(@bit.ObjectId, String)] raise @bit.GitError {
  wasm_http_not_available_async()
}
