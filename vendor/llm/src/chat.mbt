///|
/// JsonChatToolCall represents a function call in JSON chat loop.
pub(all) struct JsonChatToolCall {
  id : String
  name : String
  arguments : Json
}

///|
pub fn JsonChatToolCall::new(
  id : String,
  name : String,
  arguments : Json,
) -> JsonChatToolCall {
  { id, name, arguments }
}

///|
/// JsonChatResponse is the per-step response from a model callback.
pub(all) struct JsonChatResponse {
  content : String
  tool_calls : Array[JsonChatToolCall]
  reasoning_content : String?
}

///|
pub fn JsonChatResponse::new(
  content : String,
  tool_calls : Array[JsonChatToolCall],
  reasoning_content : String?,
) -> JsonChatResponse {
  { content, tool_calls, reasoning_content }
}

///|
/// JsonChatLoopResult is the final result of run_json_chat_loop.
pub(all) struct JsonChatLoopResult {
  final_content : String
  messages : Array[Json]
  iterations : Int
}

///|
pub fn run_json_chat_loop(
  messages : Array[Json],
  tools : Array[Json],
  max_iterations : Int,
  chat : (Array[Json], Array[Json]) -> JsonChatResponse,
  execute_tool : (String, Json) -> String,
  fallback_content? : String = "I've completed processing but have no response to give.",
) -> JsonChatLoopResult {
  let current_messages = messages
  let mut iteration = 0
  let mut final_content : String? = None
  while iteration < max_iterations {
    iteration = iteration + 1
    let response = chat(current_messages, tools)
    if response.tool_calls.is_empty() {
      final_content = Some(response.content)
      break
    }
    current_messages.push(
      build_assistant_message(
        response.content,
        response.tool_calls,
        response.reasoning_content,
      ),
    )
    for tc in response.tool_calls {
      let result = execute_tool(tc.name, tc.arguments)
      current_messages.push(build_tool_result_message(tc.id, tc.name, result))
    }
  }
  {
    final_content: match final_content {
      Some(c) => c
      None => fallback_content
    },
    messages: current_messages,
    iterations: iteration,
  }
}

///|
fn build_assistant_message(
  content : String,
  tool_calls : Array[JsonChatToolCall],
  reasoning_content : String?,
) -> Json {
  let msg : Map[String, Json] = Map([])
  msg["role"] = ToJson::to_json("assistant")
  msg["content"] = ToJson::to_json(content)
  if !tool_calls.is_empty() {
    let arr : Array[Json] = []
    for tc in tool_calls {
      arr.push(tool_call_to_openai_json(tc))
    }
    msg["tool_calls"] = Json::array(arr)
  }
  match reasoning_content {
    Some(reasoning) =>
      if !reasoning.is_empty() {
        msg["reasoning_content"] = ToJson::to_json(reasoning)
      }
    None => ()
  }
  Json::object(msg)
}

///|
fn build_tool_result_message(
  tool_call_id : String,
  tool_name : String,
  result : String,
) -> Json {
  {
    "role": ToJson::to_json("tool"),
    "tool_call_id": ToJson::to_json(tool_call_id),
    "name": ToJson::to_json(tool_name),
    "content": ToJson::to_json(result),
  }
}

///|
fn tool_call_to_openai_json(tc : JsonChatToolCall) -> Json {
  {
    "id": ToJson::to_json(tc.id),
    "type": ToJson::to_json("function"),
    "function": {
      "name": ToJson::to_json(tc.name),
      "arguments": ToJson::to_json(tc.arguments.stringify()),
    },
  }
}
