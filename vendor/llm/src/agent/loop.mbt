///|
/// LoopToolCall represents a function call in an agent loop step.
pub struct LoopToolCall {
  id : String
  name : String
  arguments : Json
}

///|
pub fn LoopToolCall::new(
  id : String,
  name : String,
  arguments : Json,
) -> LoopToolCall {
  { id, name, arguments }
}

///|
/// LoopResponse is the per-step response from a model callback.
pub struct LoopResponse {
  content : String
  tool_calls : Array[LoopToolCall]
  reasoning_content : String?
}

///|
pub fn LoopResponse::new(
  content : String,
  tool_calls : Array[LoopToolCall],
  reasoning_content : String?,
) -> LoopResponse {
  { content, tool_calls, reasoning_content }
}

///|
pub(open) trait ChatProvider {
  fn chat(Self, messages : Array[Json], tools : Array[Json], model : String) -> LoopResponse
}

///|
priv struct CallbackChatProvider {
  handler : (Array[Json], Array[Json], String) -> LoopResponse
}

///|
pub fn callback_chat_provider(
  handler : (Array[Json], Array[Json], String) -> LoopResponse,
) -> &ChatProvider {
  CallbackChatProvider::{ handler, }
}

///|
impl ChatProvider for CallbackChatProvider with fn chat(
  self,
  messages,
  tools,
  model,
) {
  (self.handler)(messages, tools, model)
}

///|
/// AgentTurnResult is the final result after loop completion.
pub struct AgentTurnResult {
  final_content : String
  messages : Array[Json]
  iterations : Int
}

///|
pub fn run_agent_loop(
  messages : Array[Json],
  tools : Array[Json],
  model : String,
  max_iterations : Int,
  chat : (Array[Json], Array[Json], String) -> LoopResponse,
  execute_tool : (String, Json) -> String,
  fallback_content? : String = "I've completed processing but have no response to give.",
) -> AgentTurnResult {
  let result = @llm.run_json_chat_loop(
    messages,
    tools,
    max_iterations,
    fn(messages, tools) {
      let response = chat(messages, tools, model)
      loop_response_to_llm(response)
    },
    execute_tool,
    fallback_content~,
  )
  {
    final_content: result.final_content,
    messages: result.messages,
    iterations: result.iterations,
  }
}

///|
pub fn run_agent_loop_with_provider(
  messages : Array[Json],
  tools : Array[Json],
  provider : &ChatProvider,
  model : String,
  max_iterations : Int,
  execute_tool : (String, Json) -> String,
  fallback_content? : String = "I've completed processing but have no response to give.",
) -> AgentTurnResult {
  run_agent_loop(
    messages,
    tools,
    model,
    max_iterations,
    fn(messages, tools, model) {
      (provider : &ChatProvider).chat(messages, tools, model)
    },
    execute_tool,
    fallback_content~,
  )
}

///|
fn loop_response_to_llm(response : LoopResponse) -> @llm.JsonChatResponse {
  let tool_calls : Array[@llm.JsonChatToolCall] = []
  for tc in response.tool_calls {
    tool_calls.push(@llm.JsonChatToolCall::new(tc.id, tc.name, tc.arguments))
  }
  @llm.JsonChatResponse::new(
    response.content,
    tool_calls,
    response.reasoning_content,
  )
}
