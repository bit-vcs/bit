///|
/// JSON Schema subset validation for tool input.
/// Compatible with OpenAI-style object schemas.

///|
pub fn validate_tool_input(input : Json, schema : Json) -> Array[String] {
  let root_type = match schema_string_field(schema, "type") {
    Some(t) => t
    None => "object"
  }
  if root_type != "object" {
    return ["Schema must be object type, got " + "\"" + root_type + "\""]
  }
  validate_tool_input_internal(input, schema, "")
}

///|
pub fn validate_params(input : Json, schema : Json) -> Array[String] {
  validate_tool_input(input, schema)
}

///|
fn validate_tool_input_internal(
  value : Json,
  schema : Json,
  path : String,
) -> Array[String] {
  let t = match schema_string_field(schema, "type") {
    Some(type_) => type_
    None => "object"
  }
  let label = if path.is_empty() { "parameter" } else { path }
  match t {
    "string" =>
      match value {
        String(s) => {
          let errors : Array[String] = []
          validate_enum(value, schema, label, errors)
          validate_string_range(s, schema, label, errors)
          errors
        }
        _ => [label + " should be string"]
      }
    "integer" =>
      match value {
        Number(n, ..) => {
          if n != n.floor() {
            return [label + " should be integer"]
          }
          let errors : Array[String] = []
          validate_enum(value, schema, label, errors)
          validate_number_range(n, schema, label, errors)
          errors
        }
        _ => [label + " should be integer"]
      }
    "number" =>
      match value {
        Number(n, ..) => {
          let errors : Array[String] = []
          validate_enum(value, schema, label, errors)
          validate_number_range(n, schema, label, errors)
          errors
        }
        _ => [label + " should be number"]
      }
    "boolean" =>
      if is_json_boolean(value) {
        let errors : Array[String] = []
        validate_enum(value, schema, label, errors)
        errors
      } else {
        [label + " should be boolean"]
      }
    "object" =>
      match value {
        Object(map) => {
          let errors : Array[String] = []
          validate_enum(value, schema, label, errors)
          validate_required_fields(map, schema, path, errors)
          validate_object_fields(map, schema, path, errors)
          errors
        }
        _ => [label + " should be object"]
      }
    "array" =>
      match value {
        Array(items) => {
          let errors : Array[String] = []
          validate_enum(value, schema, label, errors)
          validate_array_items(items, schema, path, errors)
          errors
        }
        _ => [label + " should be array"]
      }
    _ => []
  }
}

///|
fn validate_enum(
  value : Json,
  schema : Json,
  label : String,
  errors : Array[String],
) -> Unit {
  match schema_json_field(schema, "enum") {
    Some(Array(items)) =>
      if !json_array_contains(items, value) {
        errors.push(label + " must be one of " + Json::array(items).stringify())
      }
    _ => ()
  }
}

///|
fn validate_number_range(
  n : Double,
  schema : Json,
  label : String,
  errors : Array[String],
) -> Unit {
  match schema_number_field(schema, "minimum") {
    Some(minimum) =>
      if n < minimum {
        errors.push(label + " must be >= " + format_number(minimum))
      }
    None => ()
  }
  match schema_number_field(schema, "maximum") {
    Some(maximum) =>
      if n > maximum {
        errors.push(label + " must be <= " + format_number(maximum))
      }
    None => ()
  }
}

///|
fn validate_string_range(
  s : String,
  schema : Json,
  label : String,
  errors : Array[String],
) -> Unit {
  match schema_int_field(schema, "minLength") {
    Some(min_len) =>
      if s.length() < min_len {
        errors.push(
          label + " must be at least " + min_len.to_string() + " chars",
        )
      }
    None => ()
  }
  match schema_int_field(schema, "maxLength") {
    Some(max_len) =>
      if s.length() > max_len {
        errors.push(
          label + " must be at most " + max_len.to_string() + " chars",
        )
      }
    None => ()
  }
}

///|
fn validate_required_fields(
  map : Map[String, Json],
  schema : Json,
  path : String,
  errors : Array[String],
) -> Unit {
  match schema_json_field(schema, "required") {
    Some(Array(required_list)) =>
      for required in required_list {
        match required {
          String(field_name) =>
            if !map.contains(field_name) {
              errors.push("missing required " + dot_path(path, field_name))
            }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn validate_object_fields(
  map : Map[String, Json],
  schema : Json,
  path : String,
  errors : Array[String],
) -> Unit {
  let props = match schema_object_field(schema, "properties") {
    Some(p) => p
    None => Map([])
  }
  for entry in map.to_array() {
    let key = entry.0
    let val = entry.1
    match props.get(key) {
      Some(prop_schema) =>
        errors.append(
          validate_tool_input_internal(val, prop_schema, dot_path(path, key)),
        )
      None => ()
    }
  }
}

///|
fn validate_array_items(
  items : Array[Json],
  schema : Json,
  path : String,
  errors : Array[String],
) -> Unit {
  match schema_json_field(schema, "items") {
    Some(item_schema) =>
      for i, item in items {
        errors.append(
          validate_tool_input_internal(item, item_schema, index_path(path, i)),
        )
      }
    None => ()
  }
}

///|
fn schema_json_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn schema_object_field(obj : Json, key : String) -> Map[String, Json]? {
  match schema_json_field(obj, key) {
    Some(Object(map)) => Some(map)
    _ => None
  }
}

///|
fn schema_string_field(obj : Json, key : String) -> String? {
  match schema_json_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn schema_number_field(obj : Json, key : String) -> Double? {
  match schema_json_field(obj, key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
fn schema_int_field(obj : Json, key : String) -> Int? {
  match schema_number_field(obj, key) {
    Some(n) => Some(n.to_int())
    None => None
  }
}

///|
fn is_json_boolean(j : Json) -> Bool {
  match j {
    True => true
    False => true
    _ => false
  }
}

///|
fn json_array_contains(items : Array[Json], value : Json) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn format_number(n : Double) -> String {
  if n == n.floor() {
    n.to_int().to_string()
  } else {
    n.to_string()
  }
}

///|
fn dot_path(path : String, key : String) -> String {
  if path.is_empty() {
    key
  } else {
    path + "." + key
  }
}

///|
fn index_path(path : String, index : Int) -> String {
  if path.is_empty() {
    "[" + index.to_string() + "]"
  } else {
    path + "[" + index.to_string() + "]"
  }
}
