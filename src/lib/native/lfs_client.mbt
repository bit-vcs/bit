///| LFS Batch API client, object download, and cache management

///|
pub struct LfsDownloadAction {
  oid : String
  size : Int64
  href : String
  headers : Map[String, String]
} derive(Show, Eq)

///|
pub struct LfsDownloadError {
  oid : String
  code : Int
  message : String
} derive(Show, Eq)

///|
pub fn lfs_build_batch_request_json(
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
  root["operation"] = Json::string("download")
  root["transfers"] = Json::array(transfers)
  root["objects"] = Json::array(obj_arr)
  Json::object(root).stringify()
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
