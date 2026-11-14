///|
/// Convert a ContentBlock to JSON (Anthropic format).
pub fn ContentBlock::to_anthropic_json(self : ContentBlock) -> Json {
  match self {
    Text(s) => { "type": ToJson::to_json("text"), "text": ToJson::to_json(s) }
    ToolUse(id~, name~, input~) =>
      {
        "type": ToJson::to_json("tool_use"),
        "id": ToJson::to_json(id),
        "name": ToJson::to_json(name),
        "input": input,
      }
    ToolResult(tool_use_id~, content~, is_error~) =>
      {
        "type": ToJson::to_json("tool_result"),
        "tool_use_id": ToJson::to_json(tool_use_id),
        "content": ToJson::to_json(content),
        "is_error": ToJson::to_json(is_error),
      }
  }
}

///|
/// Convert a ContentBlock to JSON (OpenAI format).
pub fn ContentBlock::to_openai_json(self : ContentBlock) -> Json {
  match self {
    Text(s) => { "type": ToJson::to_json("text"), "text": ToJson::to_json(s) }
    ToolUse(id~, name~, input~) =>
      {
        "type": ToJson::to_json("function"),
        "id": ToJson::to_json(id),
        "function": {
          "name": ToJson::to_json(name),
          "arguments": ToJson::to_json(input.stringify()),
        },
      }
    ToolResult(tool_use_id~, content~, ..) =>
      {
        "role": ToJson::to_json("tool"),
        "tool_call_id": ToJson::to_json(tool_use_id),
        "content": ToJson::to_json(content),
      }
  }
}

///|
/// Convert a Message to Anthropic JSON format.
pub fn Message::to_anthropic_json(self : Message) -> Json {
  let content_arr = self.content.map(ContentBlock::to_anthropic_json)
  {
    "role": ToJson::to_json(self.role.to_string()),
    "content": Json::array(content_arr),
  }
}

///|
/// Convert a Message to OpenAI JSON format.
pub fn Message::to_openai_json(self : Message) -> Json {
  // For simple text-only messages, use string content
  if self.content.length() == 1 {
    match self.content[0] {
      Text(s) =>
        return {
          "role": ToJson::to_json(self.role.to_string()),
          "content": ToJson::to_json(s),
        }
      ToolResult(tool_use_id~, content~, ..) =>
        return {
          "role": ToJson::to_json("tool"),
          "tool_call_id": ToJson::to_json(tool_use_id),
          "content": ToJson::to_json(content),
        }
      _ => ()
    }
  }
  // For assistant messages with tool_use, extract tool_calls
  match self.role {
    Assistant => {
      let text_parts : Array[String] = []
      let tool_calls : Array[Json] = []
      for block in self.content {
        match block {
          Text(s) => text_parts.push(s)
          ToolUse(id~, name~, input~) =>
            tool_calls.push({
              "id": ToJson::to_json(id),
              "type": ToJson::to_json("function"),
              "function": {
                "name": ToJson::to_json(name),
                "arguments": ToJson::to_json(input.stringify()),
              },
            })
          _ => ()
        }
      }
      let result : Map[String, Json] = Map([])
      result["role"] = ToJson::to_json("assistant")
      result["content"] = ToJson::to_json(text_parts.join(""))
      if !tool_calls.is_empty() {
        result["tool_calls"] = Json::array(tool_calls)
      }
      return Json::object(result)
    }
    _ => ()
  }
  let content_arr = self.content.map(ContentBlock::to_openai_json)
  {
    "role": ToJson::to_json(self.role.to_string()),
    "content": Json::array(content_arr),
  }
}

///|
/// Helper to get a string field from a JSON object.
pub fn json_get_string(j : Json, field : String) -> String? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Helper to get an int field from a JSON object.
pub fn json_get_int(j : Json, field : String) -> Int? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
/// Helper to get a JSON object field.
pub fn json_get_object(j : Json, field : String) -> Json? {
  match j {
    Object(m) => m.get(field)
    _ => None
  }
}

///|
/// Helper to get a JSON array field.
pub fn json_get_array(j : Json, field : String) -> Array[Json]? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(Array(arr)) => Some(arr)
        _ => None
      }
    _ => None
  }
}
