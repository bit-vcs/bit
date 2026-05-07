///| GitHub API response types with JSON parsing

///|
/// GitHub Issue from REST API
pub struct GhIssue {
  number : Int
  node_id : String
  title : String
  body : String
  state : String
  user : String
  labels : Array[String]
  assignees : Array[String]
  created_at : String
  updated_at : String
}

///|
/// GitHub Pull Request from REST API
pub struct GhPullRequest {
  number : Int
  node_id : String
  title : String
  body : String
  state : String
  user : String
  head_ref : String
  head_repo : String
  base_ref : String
  labels : Array[String]
  created_at : String
  updated_at : String
  merged : Bool
  merged_at : String
}

///|
/// GitHub Comment from REST API
pub struct GhComment {
  id : Int
  node_id : String
  body : String
  user : String
  created_at : String
  updated_at : String
}

///|
fn gh_json_string(
  obj : Map[String, Json],
  key : String,
  fallback : String,
) -> String {
  match obj.get(key) {
    Some(Json::String(value)) => value
    Some(Json::Number(value, ..)) => value.to_string()
    Some(Json::True) => "true"
    Some(Json::False) => "false"
    _ => fallback
  }
}

///|
fn gh_json_int(obj : Map[String, Json], key : String, fallback : Int) -> Int {
  match obj.get(key) {
    Some(Json::Number(value, ..)) => value.to_int()
    _ => fallback
  }
}

///|
fn gh_json_nested_string(
  obj : Map[String, Json],
  key : String,
  nested_key : String,
  fallback : String,
) -> String {
  match obj.get(key) {
    Some(Json::Object(inner)) => gh_json_string(inner, nested_key, fallback)
    _ => fallback
  }
}

///|
fn gh_json_array_of_nested_strings(
  obj : Map[String, Json],
  key : String,
  nested_key : String,
) -> Array[String] {
  match obj.get(key) {
    Some(Json::Array(items)) => {
      let out : Array[String] = []
      for item in items {
        match item {
          Json::Object(inner) =>
            match inner.get(nested_key) {
              Some(Json::String(value)) => out.push(value)
              _ => ()
            }
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
fn gh_json_bool(obj : Map[String, Json], key : String, fallback : Bool) -> Bool {
  match obj.get(key) {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => fallback
  }
}

///|
pub fn GhIssue::from_json(obj : Map[String, Json]) -> GhIssue {
  {
    number: gh_json_int(obj, "number", 0),
    node_id: gh_json_string(obj, "node_id", ""),
    title: gh_json_string(obj, "title", ""),
    body: gh_json_string(obj, "body", ""),
    state: gh_json_string(obj, "state", ""),
    user: gh_json_nested_string(obj, "user", "login", ""),
    labels: gh_json_array_of_nested_strings(obj, "labels", "name"),
    assignees: gh_json_array_of_nested_strings(obj, "assignees", "login"),
    created_at: gh_json_string(obj, "created_at", ""),
    updated_at: gh_json_string(obj, "updated_at", ""),
  }
}

///|
pub fn GhPullRequest::from_json(obj : Map[String, Json]) -> GhPullRequest {
  let merged = gh_json_bool(obj, "merged", false)
  let state = if merged { "merged" } else { gh_json_string(obj, "state", "") }
  let head_repo = match obj.get("head") {
    Some(Json::Object(head)) =>
      match head.get("repo") {
        Some(Json::Object(repo)) => gh_json_string(repo, "full_name", "")
        _ => ""
      }
    _ => ""
  }
  {
    number: gh_json_int(obj, "number", 0),
    node_id: gh_json_string(obj, "node_id", ""),
    title: gh_json_string(obj, "title", ""),
    body: gh_json_string(obj, "body", ""),
    state,
    user: gh_json_nested_string(obj, "user", "login", ""),
    head_ref: gh_json_nested_string(obj, "head", "ref", ""),
    head_repo,
    base_ref: gh_json_nested_string(obj, "base", "ref", ""),
    labels: gh_json_array_of_nested_strings(obj, "labels", "name"),
    created_at: gh_json_string(obj, "created_at", ""),
    updated_at: gh_json_string(obj, "updated_at", ""),
    merged,
    merged_at: gh_json_string(obj, "merged_at", ""),
  }
}

///|
pub fn GhComment::from_json(obj : Map[String, Json]) -> GhComment {
  {
    id: gh_json_int(obj, "id", 0),
    node_id: gh_json_string(obj, "node_id", ""),
    body: gh_json_string(obj, "body", ""),
    user: gh_json_nested_string(obj, "user", "login", ""),
    created_at: gh_json_string(obj, "created_at", ""),
    updated_at: gh_json_string(obj, "updated_at", ""),
  }
}
