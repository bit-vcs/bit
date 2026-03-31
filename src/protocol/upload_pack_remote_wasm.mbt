///| Upload-pack dispatcher (wasm targets)

///| For wasm, use *_with_http functions from upload_pack_http_common.mbt

///| with your own HTTP client implementation.

///|
priv struct WasmHttpClient {
  get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError
  post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError
}

///|
let wasm_http_client_ref : Ref[WasmHttpClient?] = Ref::new(None)

///|
pub fn configure_wasm_http_client(
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Unit {
  wasm_http_client_ref.val = Some({ get: http_get, post: http_post })
}

///|
pub fn clear_wasm_http_client() -> Unit {
  wasm_http_client_ref.val = None
}

///|
fn wasm_http_client() -> WasmHttpClient raise @bit.GitError {
  match wasm_http_client_ref.val {
    Some(client) => client
    None =>
      raise @bit.GitError::ProtocolError(
        "HTTP client not configured for wasm target. Call configure_wasm_http_client(...) before upload-pack operations.",
      )
  }
}

///|
pub async fn upload_pack_info_refs(
  remote : String,
  prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  let client = wasm_http_client()
  upload_pack_info_refs_with_http(remote, prefer_v2, client.get)
}

///|
pub async fn upload_pack_request(
  remote : String,
  body : Bytes,
  prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  let client = wasm_http_client()
  upload_pack_request_with_http(remote, body, prefer_v2, client.post)
}

///|
pub async fn discover_upload_refs(
  remote : String,
  prefer_v2 : Bool,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  let client = wasm_http_client()
  discover_upload_refs_with_http(remote, prefer_v2, client.get, client.post)
}

///|
pub async fn fetch_pack(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
) -> Bytes raise @bit.GitError {
  let client = wasm_http_client()
  fetch_pack_with_http(
    remote,
    wants,
    prefer_v2,
    0,
    FilterSpec::NoFilter,
    client.get,
    client.post,
  )
}

///|
pub async fn fetch_objects(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
) -> Array[@bit.PackObject] raise @bit.GitError {
  let client = wasm_http_client()
  fetch_objects_with_http(
    remote,
    wants,
    prefer_v2,
    0,
    FilterSpec::NoFilter,
    client.get,
    client.post,
  )
}

///|
pub async fn clone_remote(
  remote : String,
  prefer_v2 : Bool,
) -> (Array[(@bit.ObjectId, String)], Array[@bit.PackObject]) raise @bit.GitError {
  let client = wasm_http_client()
  clone_with_http(
    remote,
    prefer_v2,
    0,
    FilterSpec::NoFilter,
    client.get,
    client.post,
  )
}

///|
pub async fn clone_remote_to_fs(
  remote : String,
  prefer_v2 : Bool,
  fs : &@bit.FileSystem,
  root : String,
) -> Array[(@bit.ObjectId, String)] raise @bit.GitError {
  let client = wasm_http_client()
  clone_to_fs_with_http(
    remote,
    prefer_v2,
    0,
    FilterSpec::NoFilter,
    fs,
    root,
    client.get,
    client.post,
  )
}
