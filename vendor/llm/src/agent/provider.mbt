///|
/// Adapter: agent ChatProvider backed by mizchi/llm Provider.

///|
priv struct LlmChatProvider {
  provider : &@llm.Provider
}

///|
pub fn llm_chat_provider(provider : &@llm.Provider) -> &ChatProvider {
  LlmChatProvider::{ provider, }
}

///|
impl ChatProvider for LlmChatProvider with fn chat(
  self,
  messages,
  tools,
  _model,
) {
  let llm_messages = to_llm_messages(messages)
  let llm_tools = to_llm_tools(tools)
  let result = @llm.collect(self.provider, llm_messages, tools=llm_tools)
  let tool_calls : Array[LoopToolCall] = []
  for tc in result.tool_calls {
    tool_calls.push(LoopToolCall::new(tc.id, tc.name, tc.input))
  }
  LoopResponse::new(result.text, tool_calls, None)
}

///|
fn to_llm_messages(messages : Array[Json]) -> Array[@llm.Message] {
  let out : Array[@llm.Message] = []
  for msg in messages {
    match to_llm_message(msg) {
      Some(m) => out.push(m)
      None => ()
    }
  }
  out
}

///|
fn to_llm_message(msg : Json) -> @llm.Message? {
  let role = match provider_json_get_string_field(msg, "role") {
    Some(r) => r
    None => return None
  }
  match role {
    "system" => Some(@llm.Message::system(json_message_text(msg)))
    "user" => Some(@llm.Message::user(json_message_text(msg)))
    "assistant" => Some(assistant_json_to_llm(msg))
    "tool" => Some(tool_json_to_llm(msg))
    _ => Some(@llm.Message::user(json_message_text(msg)))
  }
}

///|
fn assistant_json_to_llm(msg : Json) -> @llm.Message {
  let blocks : Array[@llm.ContentBlock] = []
  let text = json_message_text(msg)
  if !text.is_empty() {
    blocks.push(@llm.Text(text))
  }
  match provider_json_get_json_field(msg, "tool_calls") {
    Some(Array(calls)) =>
      for call in calls {
        match tool_call_json_to_block(call) {
          Some(block) => blocks.push(block)
          None => ()
        }
      }
    _ => ()
  }
  if blocks.is_empty() {
    blocks.push(@llm.Text(""))
  }
  { role: @llm.Assistant, content: blocks }
}

///|
fn tool_json_to_llm(msg : Json) -> @llm.Message {
  let tool_use_id = match provider_json_get_string_field(msg, "tool_call_id") {
    Some(id) => id
    None => ""
  }
  let content = json_message_text(msg)
  let is_error = content.has_prefix("Error:")
  {
    role: @llm.Tool,
    content: [@llm.ToolResult(tool_use_id~, content~, is_error~)],
  }
}

///|
fn tool_call_json_to_block(call : Json) -> @llm.ContentBlock? {
  let id = match provider_json_get_string_field(call, "id") {
    Some(v) => v
    None => ""
  }
  let function_obj = match provider_json_get_object_field(call, "function") {
    Some(obj) => obj
    None => return None
  }
  let name = match map_get_string(function_obj, "name") {
    Some(v) => v
    None => ""
  }
  if name.is_empty() {
    return None
  }
  let input = match function_obj.get("arguments") {
    Some(String(s)) => @json.parse(s) catch { _ => Json::null() }
    Some(json) => json
    None => Json::null()
  }
  Some(@llm.ToolUse(id~, name~, input~))
}

///|
fn to_llm_tools(tools : Array[Json]) -> Array[@llm.ToolDef] {
  let reg = @llm.ToolRegistry::new()
  for tool in tools {
    match provider_json_get_object_field(tool, "function") {
      Some(function_obj) => {
        let name = match map_get_string(function_obj, "name") {
          Some(v) => v
          None => ""
        }
        if name.is_empty() {
          continue
        }
        let description = match map_get_string(function_obj, "description") {
          Some(v) => v
          None => ""
        }
        let parameters = match function_obj.get("parameters") {
          Some(p) => p
          None => Json::null()
        }
        reg.register(name, description, parameters, fn(_input) { "" })
      }
      None => ()
    }
  }
  reg.get_defs()
}

///|
fn json_message_text(msg : Json) -> String {
  match provider_json_get_json_field(msg, "content") {
    Some(String(s)) => s
    Some(Array(parts)) => {
      let buf = StringBuilder::new()
      for part in parts {
        match part {
          Object(part_obj) =>
            match map_get_string(part_obj, "type") {
              Some("text") =>
                match map_get_string(part_obj, "text") {
                  Some(t) => buf.write_string(t)
                  None => ()
                }
              _ => ()
            }
          _ => ()
        }
      }
      buf.to_string()
    }
    Some(other) => other.stringify()
    None => ""
  }
}

///|
fn provider_json_get_json_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn provider_json_get_object_field(
  obj : Json,
  key : String,
) -> Map[String, Json]? {
  match provider_json_get_json_field(obj, key) {
    Some(Object(map)) => Some(map)
    _ => None
  }
}

///|
fn provider_json_get_string_field(obj : Json, key : String) -> String? {
  match provider_json_get_json_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn map_get_string(map : Map[String, Json], key : String) -> String? {
  match map.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}
