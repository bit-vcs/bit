///| Upload-pack over HTTP - common logic (all targets)

///| Uses HTTP client functions passed as arguments

///|
pub async fn upload_pack_info_refs_with_http(
  remote : String,
  prefer_v2 : Bool,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  @protocol.upload_pack_info_refs_with_http(remote, prefer_v2, http_get)
}

///|
pub async fn upload_pack_request_with_http(
  remote : String,
  body : Bytes,
  prefer_v2 : Bool,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  @protocol.upload_pack_request_with_http(remote, body, prefer_v2, http_post)
}

///|
pub async fn discover_upload_refs_with_http(
  remote : String,
  prefer_v2 : Bool,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  @protocol.ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  @protocol.discover_upload_refs_with_http(
    remote, prefer_v2, http_get, http_post,
  )
}

///|
pub async fn fetch_pack_with_http(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
  depth : Int,
  filter : @protocol.FilterSpec,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  @protocol.fetch_pack_with_http(
    remote, wants, prefer_v2, depth, filter, http_get, http_post,
  )
}

///|
pub async fn fetch_objects_with_http(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
  depth : Int,
  filter : @protocol.FilterSpec,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Array[@bit.PackObject] raise @bit.GitError {
  @protocol.fetch_objects_with_http(
    remote, wants, prefer_v2, depth, filter, http_get, http_post,
  )
}

///|
pub async fn clone_with_http(
  remote : String,
  prefer_v2 : Bool,
  depth : Int,
  filter : @protocol.FilterSpec,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> (Array[(@bit.ObjectId, String)], Array[@bit.PackObject]) raise @bit.GitError {
  @protocol.clone_with_http(
    remote, prefer_v2, depth, filter, http_get, http_post,
  )
}

///|
pub async fn clone_to_fs_with_http(
  remote : String,
  prefer_v2 : Bool,
  depth : Int,
  filter : @protocol.FilterSpec,
  fs : &@bit.FileSystem,
  root : String,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
  no_checkout? : Bool = false,
) -> Array[(@bit.ObjectId, String)] raise @bit.GitError {
  @protocol.clone_to_fs_with_http(
    remote,
    prefer_v2,
    depth,
    filter,
    fs,
    root,
    http_get,
    http_post,
    no_checkout~,
  )
}
