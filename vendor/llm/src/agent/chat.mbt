///|
/// Message construction helpers extracted from nanobot context builder.

///|
pub fn add_tool_result(
  messages : Array[Json],
  tool_call_id : String,
  tool_name : String,
  result : String,
) -> Array[Json] {
  let out = messages
  out.push({
    "role": ToJson::to_json("tool"),
    "tool_call_id": ToJson::to_json(tool_call_id),
    "name": ToJson::to_json(tool_name),
    "content": ToJson::to_json(result),
  })
  out
}

///|
pub fn add_assistant_message(
  messages : Array[Json],
  content : String?,
  tool_calls : Array[Json]?,
  reasoning_content : String?,
) -> Array[Json] {
  let out = messages
  let msg : Map[String, Json] = Map([])
  msg["role"] = ToJson::to_json("assistant")
  msg["content"] = match content {
    Some(text) => ToJson::to_json(text)
    None => ToJson::to_json("")
  }
  match tool_calls {
    Some(calls) =>
      if !calls.is_empty() {
        msg["tool_calls"] = Json::array(calls)
      }
    None => ()
  }
  match reasoning_content {
    Some(reasoning) =>
      if !reasoning.is_empty() {
        msg["reasoning_content"] = ToJson::to_json(reasoning)
      }
    None => ()
  }
  out.push(Json::object(msg))
  out
}
