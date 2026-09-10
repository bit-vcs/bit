///|
/// JSON encoding for the WAL image.
///
/// The image is small and is read by a human when something has gone wrong in
/// a bucket, so it is stored as JSON rather than a packed binary format.
/// Payloads — the things that are actually large — never pass through here;
/// entries carry only their keys.

///|
fn json_string(
  obj : Map[String, Json],
  key : String,
  fallback : String,
) -> String {
  match obj.get(key) {
    Some(Json::String(value)) => value
    _ => fallback
  }
}

///|
fn json_int64(obj : Map[String, Json], key : String, fallback : Int64) -> Int64 {
  match obj.get(key) {
    Some(Json::Number(value, ..)) => value.to_int64()
    _ => fallback
  }
}

///|
fn json_int(obj : Map[String, Json], key : String, fallback : Int) -> Int {
  match obj.get(key) {
    Some(Json::Number(value, ..)) => value.to_int()
    _ => fallback
  }
}

///|
fn json_string_array(obj : Map[String, Json], key : String) -> Array[String] {
  let out : Array[String] = []
  match obj.get(key) {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::String(value) => out.push(value)
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
fn string_array_json(values : Array[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}

///|
fn entry_json(entry : WalEntry) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["seq"] = Json::number(entry.seq.to_double())
  obj["kind"] = Json::string(entry.kind)
  obj["payload_keys"] = string_array_json(entry.payload_keys)
  obj["data"] = Json::string(entry.data)
  obj["idempotency_key"] = Json::string(entry.idempotency_key)
  Json::object(obj)
}

///|
fn entry_of_json(value : Json) -> WalEntry? {
  guard value is Json::Object(obj) else { return None }
  Some({
    seq: json_int64(obj, "seq", 0L),
    kind: json_string(obj, "kind", ""),
    payload_keys: json_string_array(obj, "payload_keys"),
    data: json_string(obj, "data", ""),
    idempotency_key: json_string(obj, "idempotency_key", ""),
  })
}

///|
pub fn encode_image(image : WalImage) -> Bytes {
  let entries : Array[Json] = []
  for entry in image.entries {
    entries.push(entry_json(entry))
  }
  let obj : Map[String, Json] = Map([])
  obj["version"] = Json::number(image.version.to_double())
  obj["snapshot"] = Json::string(image.snapshot)
  obj["snapshot_seq"] = Json::number(image.snapshot_seq.to_double())
  obj["snapshot_payloads"] = string_array_json(image.snapshot_payloads)
  obj["entries"] = Json::array(entries)
  obj["settings"] = Json::string(image.settings)
  @utf8.encode(Json::object(obj).stringify())
}

///|
pub fn decode_image(body : Bytes) -> WalImage raise @bit.GitError {
  let text = @utf8.decode_lossy(body[:])
  let parsed = @json.parse(text) catch {
    e => raise @bit.GitError::IoError("WAL image is not valid JSON: \{e}")
  }
  guard parsed is Json::Object(obj) else {
    raise @bit.GitError::IoError("WAL image is not a JSON object")
  }
  let version = json_int(obj, "version", 0)
  // A newer writer may have added fields this reader would drop on its next
  // rewrite. Refuse rather than silently truncate someone else's state.
  if version > WAL_FORMAT_VERSION {
    raise @bit.GitError::IoError(
      "WAL image format version \{version} is newer than supported " +
      "(\{WAL_FORMAT_VERSION}); upgrade before writing to this log",
    )
  }
  let entries : Array[WalEntry] = []
  match obj.get("entries") {
    Some(Json::Array(items)) =>
      for item in items {
        match entry_of_json(item) {
          Some(entry) => entries.push(entry)
          None =>
            raise @bit.GitError::IoError("WAL image has a malformed entry")
        }
      }
    _ => ()
  }
  {
    version,
    snapshot: json_string(obj, "snapshot", ""),
    snapshot_seq: json_int64(obj, "snapshot_seq", 0L),
    snapshot_payloads: json_string_array(obj, "snapshot_payloads"),
    entries,
    settings: json_string(obj, "settings", ""),
  }
}
