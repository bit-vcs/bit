///|
fn json_get_str(j : Json, field : String) -> String {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
}

///|
fn jsonrpc_response(id : Json, result : Json) -> String {
  let resp : Map[String, Json] = {}
  resp["jsonrpc"] = "2.0".to_json()
  resp["id"] = id
  resp["result"] = result
  Json::object(resp).stringify()
}

///|
fn jsonrpc_error(id : Json, code : Int, message : String) -> String {
  let err : Map[String, Json] = {}
  err["code"] = Json::number(code.to_double())
  err["message"] = message.to_json()
  let resp : Map[String, Json] = {}
  resp["jsonrpc"] = "2.0".to_json()
  resp["id"] = id
  resp["error"] = Json::object(err)
  Json::object(resp).stringify()
}

///|
fn handle_initialize(id : Json) -> String {
  let caps : Map[String, Json] = {}
  caps["tools"] = Json::object({})
  let info : Map[String, Json] = {}
  info["name"] = "bit-agent".to_json()
  info["version"] = "0.1.0".to_json()
  let result : Map[String, Json] = {}
  result["protocolVersion"] = "2024-11-05".to_json()
  result["capabilities"] = Json::object(caps)
  result["serverInfo"] = Json::object(info)
  jsonrpc_response(id, Json::object(result))
}

///|
fn build_tool_defs() -> Json {
  let result : Map[String, Json] = {}
  result["tools"] = Json::array([])
  Json::object(result)
}

///|
pub fn mcp_tool_defs() -> Json {
  build_tool_defs()
}

///|
fn handle_tools_list(id : Json) -> String {
  jsonrpc_response(id, build_tool_defs())
}

///|
fn handle_tools_call(id : Json, params : Json) -> String {
  let name = json_get_str(params, "name")
  jsonrpc_error(id, -32601, "Unknown tool: " + name)
}

///|
fn extract_request_id(json : Json) -> Json {
  match json {
    Object(m) =>
      match m.get("id") {
        Some(v) => v
        _ => Json::null()
      }
    _ => Json::null()
  }
}

///|
fn extract_request_params(json : Json) -> Json {
  match json {
    Object(m) =>
      match m.get("params") {
        Some(v) => v
        _ => Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn dispatch_request(meth : String, id : Json, params : Json) -> String {
  match meth {
    "initialize" => handle_initialize(id)
    "tools/list" => handle_tools_list(id)
    "tools/call" => handle_tools_call(id, params)
    _ => jsonrpc_error(id, -32601, "Method not found: " + meth)
  }
}

///|
pub fn mcp_dispatch_request(meth : String, id : Json, params : Json) -> String {
  dispatch_request(meth, id, params)
}

///|
fn process_message(msg : String) -> String? {
  let json = @json.parse(msg) catch {
    _ => {
      log("[mcp] Failed to parse JSON: " + msg)
      return Some(jsonrpc_error(Json::null(), -32700, "Parse error"))
    }
  }
  let meth = json_get_str(json, "method")
  let id = extract_request_id(json)
  let params = extract_request_params(json)
  if meth.is_empty() {
    return Some(jsonrpc_error(id, -32600, "Invalid Request"))
  }
  log("[mcp] method=" + meth)
  if meth == "notifications/initialized" || meth == "initialized" {
    return None
  }
  Some(dispatch_request(meth, id, params))
}

///|
pub fn mcp_process_message(msg : String) -> String? {
  process_message(msg)
}

///|
pub fn run_mcp_server() -> Unit {
  log("[mcp] bit-agent MCP server started")
  while true {
    let msg = read_message()
    if msg.is_empty() {
      break
    }
    match mcp_process_message(msg) {
      Some(response) => write_message(response)
      None => ()
    }
  }
  log("[mcp] Server stopped")
}
