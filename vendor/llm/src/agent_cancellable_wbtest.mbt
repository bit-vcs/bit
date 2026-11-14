///|
test "cancellable agent stops on cancel" {
  let make_tool_response : () -> Array[StreamEvent] = fn() {
    [
      MessageStart,
      ToolCallStart(id="call_1", name="loop_tool"),
      ToolCallEnd(id="call_1", name="loop_tool", input=Json::null()),
      MessageEnd(finish_reason=ToolUse, usage=None),
    ]
  }
  let provider = MockProvider::new([
    make_tool_response(),
    make_tool_response(),
    make_tool_response(),
  ])
  let registry = ToolRegistry::new()
  registry.register("loop_tool", "A tool", Json::null(), fn(_input) { "ok" })
  let messages : Array[Message] = [Message::user("loop")]
  let mut step_count = 0
  let done_reason = Ref("")
  run_agent_cancellable(
    BoxedProvider::new(provider),
    registry,
    messages,
    MaxSteps(10),
    fn() { step_count >= 1 },
    fn(e) {
      match e {
        StepComplete(..) => step_count = step_count + 1
        Done(reason~) => done_reason.val = reason
        _ => ()
      }
    },
  )
  @debug.debug_inspect(
    done_reason.val,
    content=(
      #|"cancelled"
    ),
  )
}

///|
test "cancellable agent runs normally without cancel" {
  let provider = MockProvider::new([
    [
      MessageStart,
      TextDelta("Hello!"),
      MessageEnd(finish_reason=Stop, usage=None),
    ],
  ])
  let registry = ToolRegistry::new()
  let messages : Array[Message] = [Message::user("hi")]
  let done_reason = Ref("")
  run_agent_cancellable(
    BoxedProvider::new(provider),
    registry,
    messages,
    MaxSteps(5),
    fn() { false },
    fn(e) {
      match e {
        Done(reason~) => done_reason.val = reason
        _ => ()
      }
    },
  )
  @debug.debug_inspect(
    done_reason.val,
    content=(
      #|"no_tool_calls"
    ),
  )
}
