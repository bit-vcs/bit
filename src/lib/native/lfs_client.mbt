///| LFS Batch API client, object download, and cache management

///|
pub struct LfsDownloadAction {
  oid : String
  size : Int64
  href : String
  headers : Map[String, String]
} derive(Debug, Eq)

///|
pub struct LfsDownloadError {
  oid : String
  code : Int
  message : String
} derive(Debug, Eq)

///|
pub struct LfsUploadAction {
  oid : String
  size : Int64
  href : String
  headers : Map[String, String]
} derive(Debug, Eq)

///|
pub struct LfsUploadError {
  oid : String
  code : Int
  message : String
} derive(Debug, Eq)

///|
fn lfs_build_batch_request_json_for_operation(
  operation : String,
  objects : Array[@bitlib.LfsPointer],
) -> String {
  let obj_arr : Array[Json] = []
  for ptr in objects {
    let m : Map[String, Json] = {}
    m["oid"] = Json::string(ptr.oid)
    m["size"] = Json::number(ptr.size.to_double())
    obj_arr.push(Json::object(m))
  }
  let transfers : Array[Json] = [Json::string("basic")]
  let root : Map[String, Json] = {}
  root["operation"] = Json::string(operation)
  root["transfers"] = Json::array(transfers)
  root["objects"] = Json::array(obj_arr)
  Json::object(root).stringify()
}

///|
pub fn lfs_build_batch_request_json(
  objects : Array[@bitlib.LfsPointer],
) -> String {
  lfs_build_batch_request_json_for_operation("download", objects)
}

///|
pub fn lfs_build_batch_upload_request_json(
  objects : Array[@bitlib.LfsPointer],
) -> String {
  lfs_build_batch_request_json_for_operation("upload", objects)
}

///|
pub fn lfs_parse_batch_response(
  body : String,
) -> (Array[LfsDownloadAction], Array[LfsDownloadError]) {
  let actions : Array[LfsDownloadAction] = []
  let errors : Array[LfsDownloadError] = []
  let parsed = @json.parse(body) catch { _ => return (actions, errors) }
  guard parsed is Json::Object(root) else { return (actions, errors) }
  guard root.get("objects") is Some(Json::Array(objects)) else {
    return (actions, errors)
  }
  for item in objects {
    guard item is Json::Object(obj) else { continue }
    let oid = match obj.get("oid") {
      Some(Json::String(s)) => s
      _ => continue
    }
    let size = match obj.get("size") {
      Some(Json::Number(n, ..)) => n.to_int64()
      _ => 0L
    }
    // Check for error first
    match obj.get("error") {
      Some(Json::Object(err_obj)) => {
        let code = match err_obj.get("code") {
          Some(Json::Number(n, ..)) => n.to_int()
          _ => 0
        }
        let message = match err_obj.get("message") {
          Some(Json::String(s)) => s
          _ => ""
        }
        errors.push({ oid, code, message })
        continue
      }
      _ => ()
    }
    // Parse download action
    guard obj.get("actions") is Some(Json::Object(acts)) else { continue }
    guard acts.get("download") is Some(Json::Object(dl)) else { continue }
    let href = match dl.get("href") {
      Some(Json::String(s)) => s
      _ => continue
    }
    let headers : Map[String, String] = {}
    match dl.get("header") {
      Some(Json::Object(hdr)) =>
        for key, value in hdr {
          match value {
            Json::String(s) => headers[key] = s
            _ => ()
          }
        }
      _ => ()
    }
    actions.push({ oid, size, href, headers })
  }
  (actions, errors)
}

///|
pub fn lfs_parse_upload_batch_response(
  body : String,
) -> (Array[LfsUploadAction], Array[LfsUploadError]) {
  let actions : Array[LfsUploadAction] = []
  let errors : Array[LfsUploadError] = []
  let parsed = @json.parse(body) catch { _ => return (actions, errors) }
  guard parsed is Json::Object(root) else { return (actions, errors) }
  guard root.get("objects") is Some(Json::Array(objects)) else {
    return (actions, errors)
  }
  for item in objects {
    guard item is Json::Object(obj) else { continue }
    let oid = match obj.get("oid") {
      Some(Json::String(s)) => s
      _ => continue
    }
    let size = match obj.get("size") {
      Some(Json::Number(n, ..)) => n.to_int64()
      _ => 0L
    }
    match obj.get("error") {
      Some(Json::Object(err_obj)) => {
        let code = match err_obj.get("code") {
          Some(Json::Number(n, ..)) => n.to_int()
          _ => 0
        }
        let message = match err_obj.get("message") {
          Some(Json::String(s)) => s
          _ => ""
        }
        errors.push({ oid, code, message })
        continue
      }
      _ => ()
    }
    guard obj.get("actions") is Some(Json::Object(acts)) else { continue }
    guard acts.get("upload") is Some(Json::Object(upload)) else { continue }
    let href = match upload.get("href") {
      Some(Json::String(s)) => s
      _ => continue
    }
    let headers : Map[String, String] = {}
    match upload.get("header") {
      Some(Json::Object(hdr)) =>
        for key, value in hdr {
          match value {
            Json::String(s) => headers[key] = s
            _ => ()
          }
        }
      _ => ()
    }
    actions.push({ oid, size, href, headers })
  }
  (actions, errors)
}

///|
/// Check if an LFS object is already cached locally.
pub fn lfs_get_cached_object(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  oid : String,
) -> Bytes? {
  let path = @bitlib.lfs_object_path(git_dir, oid)
  if rfs.is_file(path) {
    try rfs.read_file(path) catch {
      _ => None
    } noraise {
      data => Some(data)
    }
  } else {
    None
  }
}

///|
/// Send LFS batch download request and return download actions.
pub async fn lfs_batch_request(
  lfs_url : String,
  objects : Array[@bitlib.LfsPointer],
) -> (Array[LfsDownloadAction], Array[LfsDownloadError]) raise @bit.GitError {
  if objects.length() == 0 {
    return ([], [])
  }
  let batch_url = lfs_url + "/objects/batch"
  let body_str = lfs_build_batch_request_json(objects)
  let body = @utf8.encode(body_str)
  let headers : Map[String, String] = {}
  headers["Content-Type"] = "application/vnd.git-lfs+json"
  headers["Accept"] = "application/vnd.git-lfs+json"
  let (response, data) = @bitnative.native_http_post(batch_url, body, headers)
  if response.code >= 400 {
    let text = @utf8.decode_lossy(data[:])
    raise @bit.GitError::IoError(
      "LFS batch API failed (\{response.code}): \{text}",
    )
  }
  let text = @utf8.decode_lossy(data[:])
  lfs_parse_batch_response(text)
}

///|
async fn lfs_batch_upload_request_with_http(
  lfs_url : String,
  objects : Array[@bitlib.LfsPointer],
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> (Array[LfsUploadAction], Array[LfsUploadError]) raise @bit.GitError {
  if objects.length() == 0 {
    return ([], [])
  }
  let batch_url = lfs_url + "/objects/batch"
  let body_str = lfs_build_batch_upload_request_json(objects)
  let body = @utf8.encode(body_str)
  let headers : Map[String, String] = {}
  headers["Content-Type"] = "application/vnd.git-lfs+json"
  headers["Accept"] = "application/vnd.git-lfs+json"
  let (response, data) = http_post(batch_url, body, headers)
  if response.code >= 400 {
    let text = @utf8.decode_lossy(data[:])
    raise @bit.GitError::IoError(
      "LFS batch upload API failed (\{response.code}): \{text}",
    )
  }
  let text = @utf8.decode_lossy(data[:])
  lfs_parse_upload_batch_response(text)
}

///|
fn lfs_parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => "/"
    Some(0) => "/"
    Some(i) => String::unsafe_substring(path, start=0, end=i)
  }
}

///|
/// Download a single LFS object to the local cache.
/// Validates: URL scheme (HTTPS/HTTP only), SHA-256 integrity, size.
pub async fn lfs_download_single_object(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  action : LfsDownloadAction,
) -> LfsDownloadError? raise @bit.GitError {
  let dest = @bitlib.lfs_object_path(git_dir, action.oid)
  if rfs.is_file(dest) {
    return None
  }
  // Security: validate download URL scheme (prevent SSRF)
  if !@bitlib.lfs_is_valid_http_url(action.href) {
    return Some({
      oid: action.oid,
      code: 0,
      message: "Rejected non-HTTP(S) download URL: \{action.href}",
    })
  }
  let dir = lfs_parent_dir(dest)
  fs.mkdir_p(dir)
  // Security: only forward Authorization header, not arbitrary server headers
  let headers : Map[String, String] = {}
  match action.headers.get("Authorization") {
    Some(v) => headers["Authorization"] = v
    None => ()
  }
  let result = try? @bitnative.native_http_get(action.href, headers)
  match result {
    Err(err) =>
      return Some({
        oid: action.oid,
        code: 0,
        message: "Download failed: \{err}",
      })
    Ok((response, data)) => {
      if response.code >= 400 {
        return Some({
          oid: action.oid,
          code: response.code,
          message: "HTTP \{response.code}",
        })
      }
      // Security: verify SHA-256 integrity
      if !@bitlib.lfs_verify_oid(data, action.oid) {
        return Some({
          oid: action.oid,
          code: 0,
          message: "SHA-256 integrity check failed",
        })
      }
      // Security: verify size matches
      if action.size > 0L && data.length().to_int64() != action.size {
        return Some({
          oid: action.oid,
          code: 0,
          message: "Size mismatch: expected \{action.size}, got \{data.length()}",
        })
      }
      fs.write_file(dest, data)
    }
  }
  None
}

///|
/// Download LFS objects with up to 8 concurrent downloads.
pub async fn lfs_download_objects(
  fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  actions : Array[LfsDownloadAction],
) -> Array[LfsDownloadError] raise @bit.GitError {
  let errors : Array[LfsDownloadError] = []
  if actions.length() == 0 {
    return errors
  }
  let batch_size = 8
  let mut i = 0
  while i < actions.length() {
    let end = if i + batch_size < actions.length() {
      i + batch_size
    } else {
      actions.length()
    }
    let mut j = i
    while j < end {
      let action = actions[j]
      match lfs_download_single_object(fs, rfs, git_dir, action) {
        Some(err) => errors.push(err)
        None => ()
      }
      j += 1
    }
    i = end
  }
  errors
}

///|
fn lfs_collect_upload_pointers_from_pack_objects(
  objects : Array[@bit.PackObject],
) -> Array[@bitlib.LfsPointer] {
  let pointers : Array[@bitlib.LfsPointer] = []
  let seen : Map[String, Bool] = {}
  for obj in objects {
    if obj.obj_type != @bit.ObjectType::Blob {
      continue
    }
    if !@bitlib.is_lfs_pointer(obj.data) {
      continue
    }
    match @bitlib.parse_lfs_pointer(obj.data) {
      Some(ptr) =>
        if !seen.contains(ptr.oid) {
          seen[ptr.oid] = true
          pointers.push(ptr)
        }
      None => ()
    }
  }
  pointers
}

///|
async fn lfs_upload_single_object_with_http(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  action : LfsUploadAction,
  http_put : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> LfsUploadError? raise @bit.GitError {
  if !@bitlib.lfs_is_valid_http_url(action.href) {
    return Some({
      oid: action.oid,
      code: 0,
      message: "Rejected non-HTTP(S) upload URL: \{action.href}",
    })
  }
  let data = match @bitlib.lfs_get_cached_content(rfs, git_dir, action.oid) {
    Some(content) => content
    None =>
      return Some({
        oid: action.oid,
        code: 0,
        message: "LFS object is not cached locally",
      })
  }
  if !@bitlib.lfs_verify_oid(data, action.oid) {
    return Some({
      oid: action.oid,
      code: 0,
      message: "SHA-256 integrity check failed",
    })
  }
  if action.size > 0L && data.length().to_int64() != action.size {
    return Some({
      oid: action.oid,
      code: 0,
      message: "Size mismatch: expected \{action.size}, got \{data.length()}",
    })
  }
  let headers : Map[String, String] = {}
  for item in action.headers.to_array() {
    let (key, value) = item
    headers[key] = value
  }
  if !headers.contains("Content-Type") {
    headers["Content-Type"] = "application/octet-stream"
  }
  let (response, _) = http_put(action.href, data, headers)
  if response.code < 200 || response.code >= 300 {
    Some({
      oid: action.oid,
      code: response.code,
      message: "HTTP \{response.code}",
    })
  } else {
    None
  }
}

///|
async fn lfs_upload_objects_with_http(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  actions : Array[LfsUploadAction],
  http_put : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Array[LfsUploadError] raise @bit.GitError {
  let errors : Array[LfsUploadError] = []
  for action in actions {
    match lfs_upload_single_object_with_http(rfs, git_dir, action, http_put) {
      Some(err) => errors.push(err)
      None => ()
    }
  }
  errors
}

///|
async fn lfs_upload_pack_objects_with_http(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  lfs_url : String,
  objects : Array[@bit.PackObject],
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
  http_put : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Array[LfsUploadError] raise @bit.GitError {
  let pointers = lfs_collect_upload_pointers_from_pack_objects(objects)
  if pointers.length() == 0 {
    return []
  }
  let (actions, batch_errors) = lfs_batch_upload_request_with_http(
    lfs_url, pointers, http_post,
  )
  let errors : Array[LfsUploadError] = []
  for err in batch_errors {
    errors.push(err)
  }
  let upload_errors = lfs_upload_objects_with_http(
    rfs, git_dir, actions, http_put,
  )
  for err in upload_errors {
    errors.push(err)
  }
  errors
}

///|
fn lfs_upload_url_for_remote(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  remote_url : String,
  remote_name? : String = "",
) -> String {
  let config_path = git_dir + "/config"
  let lfs_url = match
    @bitlib.read_config_value(rfs, config_path, "lfs", "url") {
    Some(v) => v
    None => ""
  }
  let remote_lfs_url = if remote_name.length() > 0 {
    match
      @bitlib.read_config_value(
        rfs,
        config_path,
        "remote \"\{remote_name}\"",
        "lfsurl",
      ) {
      Some(v) => v
      None => ""
    }
  } else {
    ""
  }
  @bitlib.resolve_lfs_url_from_config(lfs_url~, remote_lfs_url~, remote_url~)
}

///|
pub async fn lfs_upload_pack_objects(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  remote_url : String,
  objects : Array[@bit.PackObject],
  remote_name? : String = "",
) -> Array[LfsUploadError] raise @bit.GitError {
  let pointers = lfs_collect_upload_pointers_from_pack_objects(objects)
  if pointers.length() == 0 {
    return []
  }
  let lfs_url = lfs_upload_url_for_remote(
    rfs,
    git_dir,
    remote_url,
    remote_name~,
  )
  if !@bitlib.lfs_is_valid_http_url(lfs_url) {
    raise @bit.GitError::IoError(
      "LFS server URL must use http:// or https:// scheme, got: \{lfs_url}",
    )
  }
  lfs_upload_pack_objects_with_http(
    rfs, git_dir, lfs_url, objects, @bitnative.native_http_post, @bitnative.native_http_put,
  )
}
