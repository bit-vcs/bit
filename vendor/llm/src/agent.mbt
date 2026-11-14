///|
/// StopCondition controls when the agent loop should stop.
pub(all) enum StopCondition {
  MaxSteps(Int)
  OnFinish
}

///|
/// AgentEvent represents events emitted during agent execution.
pub(all) enum AgentEvent {
  Stream(StreamEvent)
  ToolExecute(name~ : String, input~ : Json)
  ToolResult(name~ : String, result~ : String, is_error~ : Bool)
  StepComplete(step~ : Int)
  Done(reason~ : String)
}

///|
/// run_agent executes a tool loop with the given provider and tools.
pub fn run_agent(
  provider : BoxedProvider,
  registry : ToolRegistry,
  messages : Array[Message],
  stop : StopCondition,
  on_event : (AgentEvent) -> Unit,
) -> Unit {
  let max_steps = match stop {
    MaxSteps(n) => n
    OnFinish => 100
  }
  let tool_defs = registry.get_defs()
  for step = 0 {
    if step >= max_steps {
      on_event(Done(reason="max_steps"))
      break
    }
    // Collect events from this step
    let text_buf = StringBuilder::new()
    let pending_tool_calls : Array[ToolCall] = []
    let finish_reason : Ref[FinishReason] = Ref(Stop)
    let handler : StreamHandler = {
      on_event: fn(event) {
        on_event(Stream(event))
        match event {
          TextDelta(s) => text_buf.write_string(s)
          ToolCallEnd(id~, name~, input~) =>
            pending_tool_calls.push({ id, name, input })
          MessageEnd(finish_reason=fr, ..) => finish_reason.val = fr
          _ => ()
        }
      },
    }
    provider.stream(messages, tool_defs, handler)
    // Build assistant message from collected data
    let assistant_content : Array[ContentBlock] = []
    let text = text_buf.to_string()
    if !text.is_empty() {
      assistant_content.push(Text(text))
    }
    for tc in pending_tool_calls {
      assistant_content.push(ToolUse(id=tc.id, name=tc.name, input=tc.input))
    }
    if !assistant_content.is_empty() {
      messages.push({ role: Assistant, content: assistant_content })
    }
    // If no tool calls, we're done
    if pending_tool_calls.is_empty() {
      on_event(Done(reason="no_tool_calls"))
      break
    }
    // Execute tools and add results
    for tc in pending_tool_calls {
      on_event(ToolExecute(name=tc.name, input=tc.input))
      let (result, is_error) = registry.execute(tc.name, tc.input)
      on_event(ToolResult(name=tc.name, result~, is_error~))
      messages.push({
        role: Tool,
        content: [ToolResult(tool_use_id=tc.id, content=result, is_error~)],
      })
    }
    on_event(StepComplete(step~))
    continue step + 1
  }
}
