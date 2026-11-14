///| Cancellable version of run_agent

///|
pub fn run_agent_cancellable(
  provider : BoxedProvider,
  registry : ToolRegistry,
  messages : Array[Message],
  stop : StopCondition,
  should_cancel : () -> Bool,
  on_event : (AgentEvent) -> Unit,
) -> Unit {
  let max_steps = match stop {
    MaxSteps(n) => n
    OnFinish => 100
  }
  let tool_defs = registry.get_defs()
  for step = 0 {
    if should_cancel() {
      on_event(Done(reason="cancelled"))
      break
    }
    if step >= max_steps {
      on_event(Done(reason="max_steps"))
      break
    }
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
    if pending_tool_calls.is_empty() {
      on_event(Done(reason="no_tool_calls"))
      break
    }
    for tc in pending_tool_calls {
      if should_cancel() {
        on_event(Done(reason="cancelled"))
        return
      }
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
