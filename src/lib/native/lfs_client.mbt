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
